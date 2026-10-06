import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createSign } from 'node:crypto';

const DRIVE_API = 'https://www.googleapis.com/drive/v3';
const DRIVE_UPLOAD_API = 'https://www.googleapis.com/upload/drive/v3/files';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FOLDER_MIME = 'application/vnd.google-apps.folder';

type DriveFile = { id: string; name?: string; mimeType?: string };

type DriveUpload = {
  id: string;
  name: string;
  mimeType: string;
  webViewLink: string;
  remoteUrl: string;
  folderId: string;
  folderPath: string;
};

const base64Url = (value: string | Buffer) =>
  Buffer.from(value).toString('base64url');

@Injectable()
export class GoogleDriveService {
  private accessToken: { value: string; expiresAt: number } | null = null;
  private readonly folderCache = new Map<string, string>();

  constructor(private readonly config: ConfigService) {}

  isConfigured() {
    const hasRoot = Boolean(this.config.get('GOOGLE_DRIVE_FOLDER_ID'));
    const hasOAuth = Boolean(
      this.config.get('GOOGLE_DRIVE_CLIENT_ID') &&
        this.config.get('GOOGLE_DRIVE_CLIENT_SECRET') &&
        this.config.get('GOOGLE_DRIVE_REFRESH_TOKEN'),
    );
    const hasServiceAccount = Boolean(
      this.config.get('GOOGLE_DRIVE_CLIENT_EMAIL') &&
        this.config.get('GOOGLE_DRIVE_PRIVATE_KEY'),
    );
    return hasRoot && (hasOAuth || hasServiceAccount);
  }

  async upload(
    buffer: Buffer,
    input: {
      name: string;
      mimeType: string;
      folderPath: string;
    },
  ): Promise<DriveUpload> {
    const rootId = this.config.get<string>('GOOGLE_DRIVE_FOLDER_ID');
    if (!rootId || !this.isConfigured()) {
      throw new ServiceUnavailableException(
        'Google Drive chưa được cấu hình. Hãy kiểm tra GOOGLE_DRIVE_FOLDER_ID và bộ OAuth (GOOGLE_DRIVE_CLIENT_ID, GOOGLE_DRIVE_CLIENT_SECRET, GOOGLE_DRIVE_REFRESH_TOKEN) hoặc Service Account.',
      );
    }

    const token = await this.getAccessToken();
    const folderId = await this.ensureFolderPath(
      token,
      rootId,
      input.folderPath,
    );
    const boundary = `anzen_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    const metadata = JSON.stringify({
      name: input.name,
      parents: [folderId],
    });
    const body = Buffer.concat([
      Buffer.from(
        `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n`,
      ),
      Buffer.from(`--${boundary}\r\nContent-Type: ${input.mimeType}\r\n\r\n`),
      buffer,
      Buffer.from(`\r\n--${boundary}--`),
    ]);

    const response = await fetch(
      `${DRIVE_UPLOAD_API}?uploadType=multipart&fields=id,name,mimeType,webViewLink`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': `multipart/related; boundary=${boundary}`,
          'Content-Length': String(body.byteLength),
        },
        body,
      },
    );
    if (!response.ok) {
      throw new BadRequestException(
        `Google Drive upload thất bại: ${await response.text()}`,
      );
    }
    const file = (await response.json()) as DriveFile;

    // Images must be readable by the mobile app and Admin preview without a Drive login.
    const permissionResponse = await fetch(
      `${DRIVE_API}/files/${file.id}/permissions`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ role: 'reader', type: 'anyone' }),
      },
    );
    if (!permissionResponse.ok) {
      throw new BadRequestException(
        `Không thể cấp quyền xem ảnh Google Drive: ${await permissionResponse.text()}`,
      );
    }

    return {
      id: file.id,
      name: file.name ?? input.name,
      mimeType: file.mimeType ?? input.mimeType,
      webViewLink: `https://drive.google.com/file/d/${file.id}/view`,
      remoteUrl: `https://drive.google.com/uc?export=download&id=${file.id}`,
      folderId,
      folderPath: input.folderPath,
    };
  }

  async download(fileId: string) {
    if (!fileId || !this.isConfigured()) {
      throw new BadRequestException('Google Drive chưa được cấu hình');
    }
    const token = await this.getAccessToken();
    const response = await fetch(
      `${DRIVE_API}/files/${encodeURIComponent(fileId)}?alt=media`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (!response.ok) {
      throw new BadRequestException(
        `Không thể tải ảnh từ Google Drive: ${await response.text()}`,
      );
    }
    return {
      buffer: Buffer.from(await response.arrayBuffer()),
      mimeType: response.headers.get('content-type') || 'application/octet-stream',
    };
  }

  async remove(fileId: string) {
    if (!fileId || !this.isConfigured()) return;
    const token = await this.getAccessToken();
    const response = await fetch(
      `${DRIVE_API}/files/${encodeURIComponent(fileId)}`,
      {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      },
    );
    if (!response.ok && response.status !== 404) {
      throw new BadRequestException(
        `Không thể xóa ảnh Google Drive: ${await response.text()}`,
      );
    }
  }

  private async ensureFolderPath(token: string, rootId: string, path: string) {
    let parentId = rootId;
    for (const name of path
      .split('/')
      .map((value) => value.trim())
      .filter(Boolean)) {
      const cacheKey = `${parentId}/${name}`;
      const cached = this.folderCache.get(cacheKey);
      if (cached) {
        parentId = cached;
        continue;
      }
      const query = new URLSearchParams({
        q: `'${parentId}' in parents and name = '${name.replaceAll("'", "\\'")}' and mimeType = '${FOLDER_MIME}' and trashed = false`,
        spaces: 'drive',
        fields: 'files(id,name)',
        pageSize: '1',
      });
      const foundResponse = await fetch(`${DRIVE_API}/files?${query}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!foundResponse.ok) {
        throw new BadRequestException(
          `Không thể đọc folder Google Drive: ${await foundResponse.text()}`,
        );
      }
      const found = (await foundResponse.json()) as { files?: DriveFile[] };
      const existing = found.files?.[0];
      if (existing?.id) {
        parentId = existing.id;
        this.folderCache.set(cacheKey, parentId);
        continue;
      }
      const createdResponse = await fetch(`${DRIVE_API}/files?fields=id,name`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name,
          mimeType: FOLDER_MIME,
          parents: [parentId],
        }),
      });
      if (!createdResponse.ok) {
        throw new BadRequestException(
          `Không thể tạo folder Google Drive: ${await createdResponse.text()}`,
        );
      }
      const created = (await createdResponse.json()) as DriveFile;
      parentId = created.id;
      this.folderCache.set(cacheKey, parentId);
    }
    return parentId;
  }

  private async getAccessToken() {
    if (this.accessToken && this.accessToken.expiresAt > Date.now() + 60_000) {
      return this.accessToken.value;
    }

    const clientId = this.config.get<string>('GOOGLE_DRIVE_CLIENT_ID');
    const clientSecret = this.config.get<string>('GOOGLE_DRIVE_CLIENT_SECRET');
    const refreshToken = this.config.get<string>('GOOGLE_DRIVE_REFRESH_TOKEN');
    if (clientId && clientSecret && refreshToken) {
      return this.getOAuthAccessToken(clientId, clientSecret, refreshToken);
    }

    const email = this.config.get<string>('GOOGLE_DRIVE_CLIENT_EMAIL');
    const privateKey = this.config
      .get<string>('GOOGLE_DRIVE_PRIVATE_KEY')
      ?.replace(/\\n/g, '\n');
    if (!email || !privateKey)
      throw new ServiceUnavailableException(
        'Thiếu OAuth credential hoặc service account Google Drive',
      );
    const now = Math.floor(Date.now() / 1000);
    const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const payload = base64Url(
      JSON.stringify({
        iss: email,
        scope: 'https://www.googleapis.com/auth/drive',
        aud: TOKEN_URL,
        iat: now,
        exp: now + 3600,
      }),
    );
    const unsigned = `${header}.${payload}`;
    const signer = createSign('RSA-SHA256');
    signer.update(unsigned);
    const assertion = `${unsigned}.${signer.sign(privateKey, 'base64url')}`;
    const response = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    });
    if (!response.ok)
      throw new ServiceUnavailableException(
        `Google Drive xác thực thất bại: ${await response.text()}`,
      );
    const data = (await response.json()) as {
      access_token: string;
      expires_in: number;
    };
    this.accessToken = {
      value: data.access_token,
      expiresAt: Date.now() + data.expires_in * 1000,
    };
    return data.access_token;
  }

  private async getOAuthAccessToken(
    clientId: string,
    clientSecret: string,
    refreshToken: string,
  ) {
    const response = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
        grant_type: 'refresh_token',
      }),
    });
    if (!response.ok)
      throw new ServiceUnavailableException(
        `Google Drive OAuth xác thực thất bại: ${await response.text()}`,
      );
    const data = (await response.json()) as {
      access_token: string;
      expires_in: number;
    };
    this.accessToken = {
      value: data.access_token,
      expiresAt: Date.now() + data.expires_in * 1000,
    };
    return data.access_token;
  }
}
