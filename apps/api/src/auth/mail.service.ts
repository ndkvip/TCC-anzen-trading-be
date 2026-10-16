import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer from 'nodemailer';

type SmtpSendInfo = {
  accepted: Array<string | { address: string }>;
  messageId?: string;
  response?: string;
};

type MailTransport = {
  sendMail(options: {
    from: string;
    to: string;
    subject: string;
    text: string;
    html: string;
  }): Promise<SmtpSendInfo>;
};

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter?: MailTransport;

  constructor(private readonly config: ConfigService) {}

  get configured() {
    return Boolean(
      this.config.get<string>('SMTP_HOST') ||
      this.config.get<string>('BREVO_API_KEY'),
    );
  }

  async sendVerificationOtp(email: string, otp: string) {
    await this.send({
      to: email,
      subject: 'Mã xác thực ANZEN TRADING',
      text: `Mã xác thực email của bạn là ${otp}. Mã có hiệu lực trong 10 phút.`,
      html: `<p>Mã xác thực email của bạn là:</p><p style="font-size:24px;font-weight:700;letter-spacing:6px">${otp}</p><p>Mã có hiệu lực trong 10 phút.</p>`,
      devLabel: `Registration OTP for ${email}: ${otp}`,
    });
  }

  async sendPasswordResetOtp(email: string, otp: string) {
    await this.send({
      to: email,
      subject: 'Mã đặt lại mật khẩu ANZEN TRADING',
      text: `Mã đặt lại mật khẩu của bạn là ${otp}. Mã có hiệu lực trong 10 phút.`,
      html: `<p>Mã đặt lại mật khẩu của bạn là:</p><p style="font-size:24px;font-weight:700;letter-spacing:6px">${otp}</p><p>Mã có hiệu lực trong 10 phút.</p>`,
      devLabel: `Password reset OTP for ${email}: ${otp}`,
    });
  }

  async sendResetPassword(email: string, token: string) {
    const resetUrl = `${this.config.get('ADMIN_RESET_URL') || 'http://localhost:3000/reset-password'}?token=${encodeURIComponent(token)}`;
    await this.send({
      to: email,
      subject: 'Đặt lại mật khẩu ANZEN TRADING',
      text: `Liên kết đặt lại mật khẩu có hiệu lực trong 30 phút: ${resetUrl}`,
      html: `<p>Liên kết đặt lại mật khẩu có hiệu lực trong 30 phút:</p><p><a href="${resetUrl}">Đặt lại mật khẩu</a></p>`,
      devLabel: `Password reset URL for ${email}: ${resetUrl}`,
    });
  }

  private async send(input: {
    to: string;
    subject: string;
    text: string;
    html: string;
    devLabel: string;
  }) {
    const brevoApiKey = this.config.get<string>('BREVO_API_KEY');
    if (brevoApiKey) {
      await this.sendWithBrevo(input, brevoApiKey);
      return;
    }

    const host = this.config.get<string>('SMTP_HOST');
    if (!host) {
      this.logger.warn(`SMTP/Brevo is not configured. ${input.devLabel}`);
      return;
    }

    const from = this.config.get<string>('SMTP_FROM');
    if (!from) {
      throw new Error('SMTP_FROM chưa được cấu hình');
    }

    const port = Number(this.config.get('SMTP_PORT') || 587);
    const transporter = this.getTransporter(host, port);

    try {
      const result = await transporter.sendMail({
        from,
        to: input.to,
        subject: input.subject,
        text: input.text,
        html: input.html,
      });
      const accepted = result.accepted.some((recipient) =>
        typeof recipient === 'string'
          ? recipient === input.to
          : recipient.address === input.to,
      );
      if (!accepted) {
        throw new Error(`SMTP không xác nhận người nhận ${input.to}`);
      }
      this.logger.log(
        `OTP email queued: recipient=${input.to} messageId=${result.messageId ?? 'n/a'} response=${result.response ?? 'n/a'}`,
      );
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      this.logger.error(`Không gửi được OTP email tới ${input.to}: ${detail}`);
      throw new Error(
        'Không gửi được email OTP. Kiểm tra lại email người nhận hoặc cấu hình SMTP.',
      );
    }
  }

  private async sendWithBrevo(
    input: { to: string; subject: string; text: string; html: string },
    apiKey: string,
  ) {
    const senderEmail = this.config.get<string>('BREVO_SENDER_EMAIL');
    if (!senderEmail) throw new Error('BREVO_SENDER_EMAIL chưa được cấu hình');

    try {
      const response = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
          accept: 'application/json',
          'api-key': apiKey,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          sender: {
            email: senderEmail,
            name:
              this.config.get<string>('BREVO_SENDER_NAME') || 'ANZEN TRADING',
          },
          to: [{ email: input.to }],
          subject: input.subject,
          textContent: input.text,
          htmlContent: input.html,
        }),
      });
      if (!response.ok) {
        throw new Error(
          `Brevo trả về HTTP ${response.status}: ${await response.text()}`,
        );
      }
      const result = (await response.json()) as { messageId?: string };
      this.logger.log(
        `OTP email queued via Brevo: recipient=${input.to} messageId=${result.messageId ?? 'n/a'}`,
      );
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      this.logger.error(`Không gửi được OTP email tới ${input.to}: ${detail}`);
      throw new Error(
        'Không gửi được email OTP. Kiểm tra lại cấu hình Brevo hoặc email người nhận.',
      );
    }
  }

  private getTransporter(host: string, port: number): MailTransport {
    if (this.transporter) return this.transporter;
    const created = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: {
        user: this.config.get('SMTP_USER'),
        pass: this.config.get('SMTP_PASS'),
      },
      connectionTimeout: 10_000,
      greetingTimeout: 10_000,
      socketTimeout: 15_000,
    }) as unknown as MailTransport;
    this.transporter = created;
    return created;
  }
}
