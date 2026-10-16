# TCC-ICT - Ke hoach san pham va trien khai he thong

## 1. Muc tieu san pham

TCC-ICT la workspace danh cho trader, gom hoc tap, lap plan giao dich, ghi nhat ky, theo doi hieu qua giao dich va tu danh gia trang thai moi ngay. Phien ban nay uu tien luu du lieu local tren mobile, sau do dong bo len tai khoan khi co internet.

App mobile co 5 bottom tabs:

1. Trang chu.
2. Kien thuc.
3. Nhat ky giao dich.
4. Plan giao dich.
5. Ca nhan.

Trang chu la noi dung tinh duoc dong goi trong app, khong lay noi dung dong tu admin. Cac noi dung hoc tap, nhat ky, plan va diem danh la du lieu cua user hoac duoc phan quyen.

## 2. Nguyen tac pham vi

- Chi dung tieng Viet trong phien ban dau.
- Cho phep nguoi dung tu dang ky bang email va mat khau; khong dang ky bang so dien thoai, Google, Zalo hoac mang xa hoi.
- Moi tai khoan moi dang ky co cap mac dinh la `Thuong`.
- Co 3 cap tai khoan nguoi dung: `Thuong`, `VIP 1`, `VIP 2`; co them tai khoan `Admin` cho quan tri he thong.
- Khong hien thi bang gia, chu ky thanh toan hoac thanh toan online trong phien ban nay.
- Trang chu co the xem khi chua dang nhap; Kien thuc, Nhat ky, Plan va Ca nhan yeu cau dang nhap.
- Admin co the cap, ha cap hoac khoa quyen tai khoan tu Admin Web.
- Railway host backend, PostgreSQL va Admin Web.
- Google Drive la kho luu tru va noi duyet media chung cho toan he thong.
- User co the upload hinh trong Nhat ky va Plan; admin co the xem media theo quyen.
- Mobile cache ca noi dung bai hoc, media bai hoc, du lieu Nhat ky, Plan va diem danh.
- Khong dung Vercel, Firebase App Distribution, Cloudinary, S3, VPS hoac Nginx rieng trong pham vi nay.
- Push diem danh la local notification tren thiet bi, khong can backend gui push.
- Khach hang kiem thu nghiep vu; developer kiem tra ky thuat trong luc lam, khong tach mot phase QA/UAT doc lap.

## 3. Kien truc tong the

```text
Flutter Mobile (Android/iOS)
  - App shell 5 tabs
  - Local database + media cache
  - Local notification luc 07:00 theo gio thiet bi
  - Sync queue + retry + conflict status
  - Auth/session manager
          |
          | HTTPS
          v
Railway
  - Node.js backend API
  - PostgreSQL
  - Admin Web
  - Media metadata, access control, sync API
          |
          | Google Drive API
          v
Google Drive
  - Media bai hoc
  - Media Nhat ky cua user
  - Media Plan cua user
```

Railway luu du lieu nghiep vu, metadata media, quyen truy cap va trang thai dong bo. File hinh nam tren Google Drive; mobile khong truy cap truc tiep Google Drive ma di qua API de kiem tra quyen.

## 4. Auth va phan quyen

### 4.1 Dang ky va dang nhap

- Dang ky tai khoan bang email va mat khau.
- Email phai dung dinh dang va khong duoc trung trong he thong.
- Tai khoan moi dang ky duoc gan cap `Thuong`.
- Xac minh email truoc khi su dung day du tai khoan; email xac minh co token co han va dung mot lan.
- Dang nhap bang email/mat khau.
- Quen mat khau bang email.
- Dat lai mat khau bang reset token co han va dung mot lan.
- Doi mat khau.
- Dang xuat.
- Refresh token, het han phien va khoi phuc phien.
- Moi tai khoan chi co mot thiet bi dang hoat dong. Khi may B dang nhap, phien may A bi vo hieu hoa o request tiep theo.
- Khong co dang ky bang Google, Zalo, so dien thoai hoac ma OTP trong pham vi nay.

### 4.2 Cap tai khoan va quyen hoc

| Cap tai khoan | Quyen noi dung hoc tap |
|---|---|
| Thuong | Duoc hoc thu 3 bai Co ban va 1 bai Nang cao. Cac bai con lai hien khoa. |
| VIP 1 | Mo toan bo bai Co ban va duoc hoc thu 3 bai Nang cao. Cac bai Nang cao con lai hien khoa. |
| VIP 2 | Truy cap khong gioi han toan bo bai Co ban va Nang cao. |
| Admin | Quan tri tai khoan, bai hoc, media va xem du lieu user theo quyen. |

Quy tac:

- `Thuong` la cap duy nhat nguoi dung co the tu tao tu app.
- `VIP 1` va `VIP 2` duoc cap tu Admin Web; khong co luong tu nang cap va thanh toan trong app.
- Bon bai hoc trai nghiem cua tai khoan `Thuong` gom 3 bai Co ban va 1 bai Nang cao. Danh sach bai trai nghiem duoc admin danh dau, khong phu thuoc cung nhat vao thu tu sap xep.
- Ba bai Nang cao trai nghiem cua `VIP 1` duoc admin danh dau trong Admin Web.
- Khi bam bai hoc bi khoa, `Thuong` va `VIP 1` hien modal huong dan lien he Zalo de duoc tu van/mo khoa. App khong tich hop bot Zalo hoac gui ma Zalo.
- `VIP 2` khong hien bai hoc bi khoa trong pham vi quyen hien tai.
- Cap tai khoan chi gioi han quyen truy cap Kien thuc. Ca `Thuong`, `VIP 1` va `VIP 2` deu duoc su dung Nhat ky, Plan va diem danh; `VIP 2` khong bi gioi han noi dung hoc tap.
- Backend luon kiem tra cap tai khoan, owner va quan he record; icon khoa tren UI khong thay the phan quyen server.
- User khong duoc xem du lieu Nhat ky, Plan va diem danh cua user khac.

## 5. Navigation va user flow

### 5.1 App shell

```text
Mo app
  -> Chua dang nhap: Trang chu
  -> Bam Kien thuc/Nhat ky/Plan/Ca nhan
  -> Man dang nhap hoac dang ky email
  -> Xac minh email neu chua xac minh
  -> Dang nhap thanh cong
  -> Mo khu vuc duoc chon
```

### 5.2 Dang ky tai khoan

```text
Trang dang nhap
  -> Dang ky bang email
  -> Nhap email + mat khau + xac nhan mat khau
  -> Nhan email xac minh
  -> Xac minh email
  -> Tai khoan Thuong duoc tao
  -> Quay lai dang nhap
```

### 5.3 Trang chu

```text
Trang chu
  -> Chao mung
  -> Gioi thieu app
  -> Cach su dung 5 khu vuc
  -> Chon CTA sang Dang nhap, Dang ky hoac Kien thuc
```

Noi dung Trang chu la static content trong app. Admin khong co man hinh CMS, API, upload hoac publish cho Trang chu.

### 5.4 Kien thuc

```text
Kien thuc
  -> Tim kiem trong thu vien
  -> Chon Co ban / Nang cao
  -> Kiem tra cap tai khoan
  -> Chon bai hoc mo hoac bam bai khoa
  -> Xem ly thuyet xen bai tap
  -> Chon dap an va xem giai thich
  -> Tiep tuc den ket qua bai hoc
```

### 5.5 Nhat ky giao dich

```text
Nhat ky giao dich
  -> Chon Intra day / Swing

Intra day
  -> Lich thang
  -> Bam mot ngay
  -> Danh sach nhat ky cua ngay
  -> Them/sua nhat ky
  -> Xem tong ket ngay, tuan, thang

Swing
  -> Danh sach nhat ky
  -> Them/sua nhat ky truc tiep
  -> Xem chien luoc hieu qua nhat
```

### 5.6 Plan giao dich

```text
Plan giao dich
  -> Chon Plan thang / tuan / ngay
  -> Xem list plan
  -> Tao hoac mo plan
  -> Chen plain text va image xen ke
  -> Neu la Plan ngay: chon cap thoi gian H4-M15 va/hoac H1-M5
  -> Luu nhap/hoan tat
```

### 5.7 Ca nhan va diem danh

```text
Mo app vao moi ngay
  -> Neu chua diem danh hom nay: hien modal mot lan
  -> Chon 5 tieu chi, he thong tinh tong 0-10
  -> Luu diem danh hom nay
  -> Co the bo qua va dien lai tai Ca nhan

Ca nhan
  -> Ho so tai khoan
  -> Sua diem danh cua ngay
  -> Xem toi da 30 ngay lich su
  -> Cai dat tai khoan va bao mat
  -> Dang xuat
```

## 6. Chi tiet chuc nang mobile

### 6.1 Trang chu - static

- Giao dien chao mung, gioi thieu ngan va cach su dung app.
- Gioi thieu 5 khu vuc: Trang chu, Kien thuc, Nhat ky giao dich, Plan giao dich, Ca nhan.
- CTA dan sang dang nhap, dang ky hoac Kien thuc.
- Co the xem khi chua dang nhap.
- Noi dung, hinh minh hoa va thu tu duoc dong goi cung app; thay doi noi dung can cap nhat phien ban app.
- Khong co bookmark, read-state, API noi dung hay Admin CMS cho Trang chu.

### 6.2 Kien thuc

#### Subtab va quyen

- Co 2 subtab: `Co ban` va `Nang cao`.
- Ca 3 cap tai khoan deu co the mo 2 subtab de xem danh sach bai hoc. Quyen khoa/mo duoc ap dung tren tung the bai hoc.
- `Thuong` mo duoc 3 bai Co ban va 1 bai Nang cao trai nghiem; cac the con lai co icon khoa.
- `VIP 1` mo toan bo Co ban va 3 bai Nang cao trai nghiem; cac the Nang cao con lai co icon khoa.
- `VIP 2` switch qua lai duoc giua Co ban va Nang cao khong gioi han.
- Tab Co ban giu mau chu dao theo design hien tai.
- Khi mo Nang cao, mau chu dao chuyen sang cam.
- Khi bam bai khoa voi `Thuong` hoac `VIP 1`, hien modal lien he Zalo; modal co nut dong va nut sao chep thong tin lien he.

#### Thu vien bai hoc

Moi subtab la mot list bai hoc, khong co flashcard hang ngay. Moi the bai hoc hien thi:

- Ten va mo ta ngan.
- So phan da hoan thanh, vi du `3/8 phan`.
- Progress bar.
- Trang thai da doc/chua doc.
- Bookmark.
- Trang thai da tai offline.
- Nhan cap quyen can thiet neu bai dang khoa.
- Nhan `Trai nghiem mien phi` cho bai duoc mo theo chinh sach tai khoan.

#### Noi dung bai hoc

Bai hoc co luong hoc tung buoc, cam giac giong Duolingo:

- Phan ly thuyet.
- Hinh minh hoa neu co.
- Cau hoi chon dap an.
- Phan hoi ngay sau khi chon.
- Giai thich dap an.
- Phan ly thuyet hoac bai tap tiep theo.
- Ket qua bai hoc.

Admin quyet dinh so phan ly thuyet, so cau hoi, thu tu, dap an dung, giai thich, media dinh kem va bai nao la bai trai nghiem.

#### Tim kiem, bookmark va da doc

- Tim theo ten bai, chu de va khoa hoc.
- Search co the hien ca the bai mo va the bai khoa de user biet thu vien hien co, nhung khong tra noi dung chi tiet cua bai chua co quyen.
- `Thuong` va `VIP 1` bam ket qua dang khoa se mo modal lien he Zalo.
- `VIP 2` nhan ket qua va mo duoc toan bo bai o ca hai cap.
- Bookmark bai quan trong.
- Danh dau bai da doc.
- Search phai ton trong quyen truy cap cua cap tai khoan.

#### Offline Knowledge

Mobile cache local:

- Danh sach bai hoc va metadata.
- Noi dung text, cau hoi, lua chon, dap an, giai thich.
- Tien trinh, bookmark va read-state.
- Hinh anh/media lien quan.
- Trang thai quyen tai khoan va bai da tai.

User co the hoc bai da tai khi mat mang. Tien trinh phat sinh offline duoc dua vao sync queue va dong bo khi co internet. Neu quyen bai hoc thay doi, server la nguon xac thuc quyen khi co ket noi tro lai.

### 6.3 Nhat ky giao dich

Nhat ky co 2 subtab: `Intra day` va `Swing`.

#### Subtab Intra day

- Giu nguyen layout Nhat ky hien tai dang duoc duyet.
- Man dau la lich thang.
- Mot ngay co the co nhieu nhat ky giao dich.
- Bam mot ngay mo list nhat ky cua ngay do.
- Nut `+ Them nhat ky` o goc phai phia duoi.
- Giao dich co PNL duong hien mau xanh; PNL am hien mau do; PNL bang 0 dung mau trung tinh.
- Tong ket ngay hien o cuoi trang ngay.
- Tong ket tuan va thang mo tu lich hoac bo loc khoang thoi gian.

#### Form them/sua nhat ky Intra day

- Ma tai san: combobox vua cho chon vua cho nhap. Gia tri san: `BTCUSDT`, `ETHUSDT`, `XAUUSD`, `XAGUSD`; co them lua chon `Khac` de nhap ma moi.
- Huong: `Long` hoac `Short`.
- Thoi gian vao: cho phep nhap ngay va gio.
- Thoi gian giu lenh: nhap so gio, co the nhap so le neu can; khong dung field `Thoi gian chot lenh`.
- Ty le R:R.
- PNL: nhap so tien lai/lo.
- So R: nhap ket qua theo R de tong ket duoc PNL va tong so R.
- Cap thoi gian: dropdown gom `D1-H1`, `H4-M15`, `H1-M5`, `M15-M1`.
- Cach gia di chuyen: dropdown gom cac gia tri chien luoc da chot, vi du `AMD`, `MMXM`, va `Khac`.
- Hinh qua trinh/chart: upload mot hoac nhieu hinh.
- Y tuong va ke hoach.
- Thuc hien/xu ly lenh.
- Ket qua.

PNL va So R duoc nhap thu cong trong MVP. Khong tu dong tinh PNL theo gia vao/ra, khoi luong, don bay hoac loai hop dong.

#### Tong ket Intra day

- Tong ket ngay: tong PNL tien, tong so R, so giao dich, so lenh lai/lo/hoa, ty le thang neu co du lieu.
- Tong ket tuan: cac chi so tuong tu trong pham vi tuan.
- Tong ket thang: cac chi so tuong tu trong pham vi thang.
- PNL duong va tong R duong hien mau xanh; PNL am va tong R am hien mau do.
- Dat khoi tong ket ngay ngay sau danh sach giao dich; tong ket tuan/thang dat trong man tong ket rieng de khong lam day man lich.

#### Subtab Swing

- Khong co calendar.
- Hien thi list don gian cac nhat ky Swing.
- Co nut `+ Them nhat ky` truc tiep tren man list.
- Form them/sua dung cung bo field voi Intra day, trong do giu cac field PNL, So R, Cap thoi gian, Cach gia di chuyen, hinh va ghi chu.
- Khong hien tong ket ngay, tuan, thang.
- Co khoi `Chien luoc hieu qua nhat` tren dau list. Trong MVP, mot chien luoc duoc nhom theo `Cap thoi gian + Cach gia di chuyen`, xep theo tong PNL; hien them tong So R, so giao dich va ty le lenh lai.

User co the upload nhieu hinh tu mobile. Hinh duoc luu tam local, dua qua Railway API, toi uu va luu vao Google Drive; metadata va owner luu tren PostgreSQL.

MVP ho tro plain text, tieu de, checklist, danh sach va image block theo phong cach Word/Notion cho ghi chu; khong lam collaboration realtime.

### 6.4 Plan giao dich

#### Chu ky va list

- Plan thang: tao vao dau moi thang.
- Plan tuan: tao vao moi thu Hai.
- Plan ngay: tao moi ngay.
- Plan ngay co the chi tiet cac khung thoi gian can thiet.
- Plan moi co the ke thua boi canh tu plan lon hon nhung khong sua ban goc.

#### Noi dung

- Cap tai san.
- Xu huong thang, tuan, ngay.
- Nhan dinh cac khung thoi gian.
- Vung giao dich.
- Y tuong va kich ban giao dich.
- Dieu kien xac nhan.
- Dieu kien vo hieu.
- Ghi chu ca nhan.

Khong bat buoc tach thanh nhieu card. User soan lien mach giong Word va tu chon noi dung can chen.

#### Dropdown rieng cho Plan ngay

- Chi Plan ngay moi co them truong `Cap thoi gian giao dich` dat ngay tren vung nhap plaintext.
- Dropdown co 2 gia tri: `H4-M15` va `H1-M5`.
- Cho phep chon mot hoac ca hai gia tri.
- Lua chon nay la metadata cua Plan ngay, khong chen vao noi dung plaintext va khong ap dung cho Plan thang/tuan.

#### Editor va media

- Chi co hai loai block: `text` va `image`.
- User tu quyet dinh thu tu, so luong va vi tri block.
- Chen text hoac hinh tai vi tri con tro.
- Xem preview, sua, xoa, doi vi tri, luu nhap va hoan tat.
- Hinh chart co progress upload, preview, retry va trang thai sync.
- Upload hinh moi qua Railway API; file luu tren Google Drive.
- Co the chon lai hinh da upload neu user con quyen truy cap.

### 6.5 Ca nhan va diem danh

#### Ho so va tai khoan

- Ten, avatar, email.
- Cap tai khoan: Thuong, VIP 1 hoac VIP 2.
- Trang thai tai khoan.
- Doi mat khau, dang xuat.
- Mo man `Sua diem danh` de sua ban ghi cua tung ngay trong 30 ngay gan nhat.

#### Diem danh hang ngay

- App tao lich nhac local luc `07:00` moi ngay theo mui gio va thoi gian cua thiet bi.
- Khong can backend gui push notification.
- Khi mo app, neu hom nay chua co ban ghi diem danh thi hien modal mot lan trong ngay.
- Neu user bam `De sau`, modal khong tu hien lai trong cung ngay; user co the vao tab Ca nhan de dien/sua.
- Modal diem danh ghi nhan cho ngay hien tai; truong `Gio ngu` phan anh dem truoc.
- Nam tieu chi, moi tieu chi co 5 muc:

| Tieu chi | Muc diem tu thap den cao |
|---|---|
| Tinh than/nang luong | Can kiet, Ue oai, Binh thuong, Tot, Sung suc |
| Tam ly/cam xuc | Bat on, Xao dong, Can bang, Vung vang, Ky luat tuyet doi |
| Dau oc tinh tao | Mo mang, Tan man, Tinh, Minh man, Cuc ky tap trung |
| Gio ngu | 4h, 5h, 6h, 7h, 8h |
| Ke hoach hom nay | Chua co, So sai, Co ban, Chi tiet, Hoan hao |

- Tong diem hien thi theo thang `0-10`. De giu 5 muc lua chon nhung tong toi da la 10, moi tieu chi duoc quy doi lan luot thanh `0`, `0.5`, `1`, `1.5`, `2` diem.
- He thong luu ca muc lua chon goc va diem quy doi de sau nay co the doi cach tinh ma khong mat lich su.
- Hien thi tong diem va nhan xet muc do trong man Ca nhan; khong doi mau toan bo app theo diem.

#### Luu tru va xoa lich su diem danh

- Diem danh duoc luu local ngay sau khi user bam luu.
- Khi co internet, ban ghi duoc dong bo len PostgreSQL.
- Moi user luu toi da 30 ban ghi diem danh theo ngay trong database.
- Khi them ban ghi thu 31, he thong xoa ban ghi cu nhat truoc, sau do luu ban ghi moi.
- Quy tac 30 ngay ap dung cho ca server va local cache de tranh local phinh du lieu; cac module Nhat ky, Plan va tien do hoc khong bi xoa theo quy tac nay.
- Lich su duoc xem, sua va dong bo; khong tu dong mat khi doi tuan/thang ngoai tru quy tac gioi han 30 ngay.

#### Cai dat

- Doi mat khau.
- Quan ly phien/thiet bi.
- Dang xuat.
- Thong tin ho tro va thong tin Zalo.
- Dieu khoan va chinh sach.

Khong co setting ngon ngu vi phien ban dau chi dung tieng Viet.

## 7. Offline-first va dong bo

Du lieu local gom:

- Session can thiet.
- Knowledge content, media, progress, bookmark va read-state.
- Journal Intra day, Journal Swing, trade, note, tong ket va media.
- Plan, block text/image, draft/complete, cap thoi gian Plan ngay va media.
- Toan bo lich su diem danh trong toi da 30 ngay.
- Cau hinh lich local notification luc 07:00.

Trang thai dong bo:

```text
local_only -> pending -> syncing -> synced
                         |
                         +-> failed -> retry
                         |
                         +-> conflict -> user chon ban giu
```

Quy tac:

- Khong am tham ghi de ban local bang ban server.
- Hien badge `Chi tren thiet bi`, `Dang dong bo`, `Da dong bo`, `Can xu ly xung dot`.
- Media co the luu tam local truoc khi upload.
- Retry upload media doc lap voi retry record neu mang chap chon.
- Conflict MVP xu ly theo phien ban cap nhat gan nhat va thong bao de user chon giu ban local/server; khong lam merge realtime.
- Quyen bai hoc duoc kiem tra lai voi server khi co internet; noi dung da cache khong tu dong mo rong quyen.

## 8. Admin Web tren Railway

Admin Web la mot service Next.js chay tren Railway, dung chung API va PostgreSQL. Khong co Vercel.

### 8.1 Quan ly tai khoan

- Admin dang nhap.
- Xem danh sach tai khoan tu dang ky bang email.
- Xem trang thai email: chua xac minh/da xac minh.
- Xem ngay dang ky, lan hoat dong gan nhat va trang thai tai khoan.
- Tim kiem theo email, loc theo cap tai khoan.
- Cap `Thuong`, `VIP 1` hoac `VIP 2`.
- Ha cap, khoa/mo tai khoan.
- Xem thiet bi dang hoat dong va kick session.
- Ho tro reset password.
- Khong co quan ly bang gia, don hang, thanh toan hoac chu ky VIP.

### 8.2 Quan ly Kien thuc

- Tao khoa hoc, chuong va bai hoc.
- Gan cap Co ban/Nang cao.
- Sap xep thu tu.
- Danh dau bai trai nghiem cho `Thuong`: 3 bai Co ban + 1 bai Nang cao.
- Danh dau 3 bai Nang cao trai nghiem cho `VIP 1`.
- Tao phan ly thuyet va cau hoi trac nghiem.
- Khai bao dap an dung va giai thich.
- Cau hinh so luong cau hoi.
- Sap xep noi dung ly thuyet/bai tap xen ke.
- Chon hoac upload media qua Google Drive.
- Preview va publish bai hoc.

### 8.3 Media library dung chung

Google Drive dung cho viec luu tru va duyet hinh anh trong ca he thong:

- Hinh bai hoc do admin upload/chon.
- Hinh Nhat ky do user upload.
- Hinh Plan do user upload.
- Tim kiem, preview, loc theo module/owner/trang thai.
- Gan media vao lesson, Nhat ky hoac Plan.
- Xem file id, MIME, kich thuoc, owner va trang thai sync.
- Admin xem media rieng cua user theo quyen; khong tu dong cho tat ca admin truy cap neu chua duoc cap.

Admin khong quan ly noi dung Trang chu.

### 8.4 Tra cuu du lieu user

- Tien do hoc, bai da doc, bookmark, ket qua bai tap.
- Nhat ky Intra day theo ngay, giao dich, PNL, So R, tong ket va media.
- Nhat ky Swing, chien luoc hieu qua nhat va media.
- Plan thang/tuan/ngay, cap thoi gian Plan ngay va media.
- Diem danh toi da 30 ngay cua user.
- Loc theo user, khoang thoi gian, module va trang thai sync.
- Thao tac xem/sua/xoa quan trong phai ghi log.

### 8.5 Dashboard co ban

- Tong user theo cap Thuong/VIP 1/VIP 2.
- So tai khoan da xac minh email.
- Bai hoc dang publish va bai trai nghiem.
- Tien do hoc tong quan.
- So Nhat ky/Plan/diem danh theo khoang thoi gian.
- Tong PNL va tong So R theo quyen duoc cap.
- Trang thai media upload va sync.
- Loi sync can xu ly.

## 9. Backend va media

### 9.1 Module API

- Auth/dang ky email/xac minh email/session.
- Quen, dat lai va doi mat khau.
- Users/account tiers/admin access.
- Knowledge courses/lessons/sections/questions.
- Trial lesson configuration theo cap tai khoan.
- Progress/bookmark/read-state.
- Journal Intra day days/trades/notes/summaries.
- Journal Swing trades/strategy summaries.
- PNL/So R aggregation theo ngay, tuan, thang cho Intra day.
- Plans/blocks/timeframes/daily timeframe pairs.
- Personal check-ins va retention 30 ngay.
- Local notification configuration khong can API gui push.
- Google Drive media metadata.
- Upload/download media qua API.
- Access control theo tier/owner.
- Sync changes, retry va conflict status.

### 9.2 Media flow

```text
Admin/User chon hoac upload hinh
  -> Railway API kiem tra auth/role/owner
  -> Sharp validate, resize, chuyen WebP khi phu hop
  -> Upload file vao Google Drive
  -> PostgreSQL luu file_id, module, owner, record_id, MIME, kich thuoc
  -> API tra media token/URL co han
  -> Mobile tai va cache local
```

Quy tac media:

- Mobile khong truy cap tu do vao Google Drive.
- Kiem tra MIME type, kich thuoc va so luong file.
- Resize `max-width 2560px`, loai metadata va chuyen WebP khi phu hop.
- Media Knowledge co the dung chung theo bai hoc.
- Media Nhat ky/Plan gan owner/user de phan quyen.
- Xoa lien ket an toan, tranh de file mo coi.
- Khong dung Google Drive lam database; metadata va quyen nam tren Railway.

## 10. Trien khai va dich vu ben thu ba

### 10.1 Railway

Tao mot Railway project gom:

1. PostgreSQL.
2. Node.js API.
3. Admin Web Next.js.

Cau hinh env, CORS, domain HTTPS, migration, log loi va ket noi noi bo Railway. Khong dung Vercel cho admin.

### 10.2 Google Drive

Google Drive la dich vu bat buoc cho media theo yeu cau san pham. Can mot tai khoan Google/Google Workspace va quyen Google Drive API. Chi phi luu tru phu thuoc quota/tai khoan Google dang su dung; khong them mot kho media SaaS rieng.

### 10.3 Email dang ky va quen mat khau

Can mot SMTP mailbox cua khach hang hoac dich vu email ma khach hang tu chon de gui email xac minh tai khoan va email dat lai mat khau. Estimate chi tinh phan tich hop SMTP, khong bao gom phi gui email neu nha cung cap co tinh phi.

### 10.4 Local notification

- Dung co che local notification cua Android/iOS de lap lich luc 07:00 theo gio thiet bi.
- Khong can Firebase Cloud Messaging, server cron hoac backend push.
- Lan dau app can xin quyen thong bao theo quy dinh he dieu hanh.

### 10.5 Khong bao gom

- Vercel.
- Firebase App Distribution.
- Bot Zalo, Zalo OTP va tich hop Zalo API.
- Google login, Apple login, dang ky bang so dien thoai.
- Thanh toan online, subscription, bang gia va tu dong gia han VIP.
- TestFlight, Google Play Internal Test va public store release neu chua duoc chot trong estimate rieng.
- VPS/Nginx/PM2 rieng.
- Cloudinary, Amazon S3, CDN rieng.
- Screenshot security, FLAG_SECURE, iOS screenshot listener.
- Broker integration, market data realtime, realtime collaboration.
- Backup sang cloud thu hai, monitoring nang cao, load test va security test doc lap.

## 11. Pham vi ban dau

### Bao gom

- App Flutter Android/iOS voi 5 bottom tabs.
- Trang chu static xem duoc truoc login.
- Dang ky bang email/mat khau, xac minh email, dang nhap, quen mat khau email, doi mat khau, logout va single active device.
- Cap tai khoan Thuong/VIP 1/VIP 2 va Admin Web cap quyen.
- Chinh sach trai nghiem 3 bai Co ban + 1 bai Nang cao cho Thuong; full Co ban + 3 bai Nang cao cho VIP 1; full cho VIP 2.
- Modal lien he Zalo khi user Thuong/VIP 1 bam bai hoc khoa.
- Knowledge Co ban/Nang cao, lock icon, mau cam, search, bookmark, da doc, progress, ly thuyet xen quiz va ket qua.
- Cache offline ca noi dung bai hoc va media.
- Nhat ky 2 subtab Intra day/Swing.
- Intra day calendar, nhieu giao dich/ngay, PNL, So R, mau lai/lo, cap thoi gian, cach gia di chuyen, tong ket ngay/tuan/thang.
- Swing list don gian, form giao dich tuong tu, khong tong ket theo ngay/tuan/thang, co chien luoc hieu qua nhat.
- User upload hinh trong Nhat ky va Plan.
- Plan thang/tuan/ngay, Plan ngay co multi-select H4-M15 va H1-M5, editor plain text/image lien mach.
- Ca nhan, ho so tai khoan, modal diem danh hang ngay, 5 tieu chi 5 muc, tong diem 0-10, sua diem danh va luu toi da 30 ngay.
- Local notification luc 07:00 theo gio thiet bi, khong can backend push.
- Sync queue, retry va conflict status co ban.
- Admin Web chay local trong giai doan phat trien; khi release production moi dua len Railway.
- PostgreSQL va API chay local bang Docker trong giai doan phat trien; khi release production moi dua len Railway.
- Google Drive media library dung chung.
- Admin tra cuu du lieu user theo quyen.

### Khong bao gom

- Admin CMS/API noi dung Trang chu.
- Bang gia, thanh toan, subscription hoac tu dong cap VIP.
- Bot Zalo/OTP/Zalo API.
- Dang ky Google/Apple/so dien thoai.
- Hai ngon ngu.
- Vercel va Firebase App Distribution.
- TestFlight, Google Play Internal Test va public release neu chua co estimate rieng.
- Screenshot security.
- QA/UAT doc lap do khach hang tu kiem thu.
- Cac tinh nang ngoai danh sach tren.

## 12. Ke hoach theo phase

### Phase 0 - UI/UX va app shell

Chot layout 5 bottom tabs dang co, visual system, icon, typography, cac trang thai tai khoan Thuong/VIP, subtab Nhat ky, modal khoa bai, modal diem danh va trang thai loading/empty/error.

### Phase 1 - Nen tang local

Hoan thien khung Flutter, API NestJS, Admin Next.js va PostgreSQL chay bang Docker. Cau hinh environment, CORS, TypeORM migration, health check, script khoi dong local va kiem tra ket noi Mobile -> API -> Database. Phase nay chua trien khai Railway; Railway chi duoc cau hinh o giai doan release production.

### Phase 2 - Auth, dang ky email va cap tai khoan

Dang ky email, xac minh email, dang nhap, quen mat khau email, dat lai/doi mat khau, session, single active device, hien thi cap tai khoan va Admin Web cap Thuong/VIP 1/VIP 2.

### Phase 3 - Trang chu static

Hoan thien UI Trang chu, noi dung dong goi trong app, guest access va CTA. Khong xay CMS/API cho Trang chu.

### Phase 4 - Kien thuc va chinh sach bai trai nghiem

List bai, 2 subtab, quyen theo 3 cap, lock icon, mau cam Nang cao, modal lien he Zalo, search, bookmark, read-state, progress, luong ly thuyet xen quiz, ket qua, admin CMS va media bai hoc.

### Phase 5 - Nhat ky Intra day

Giữ layout calendar hien tai, list nhieu giao dich/ngay, form field moi, asset combobox/input, PNL, So R, cap thoi gian, cach gia di chuyen, mau lai/lo, tong ket ngay/tuan/thang va offline sync.

### Phase 6 - Nhat ky Swing

Subtab Swing, list don gian, them/sua truc tiep, form tuong tu Intra day, upload hinh va khoi chien luoc hieu qua nhat.

### Phase 7 - Plan giao dich

Thu vien Plan, Plan thang/tuan/ngay, dropdown multi-select chi cho Plan ngay, editor giong Word voi plain text/image, user upload chart, draft/complete va sync.

### Phase 8 - Ca nhan va diem danh

Ho so, cap tai khoan, setting, local notification 07:00, modal diem danh mot lan/ngay, 5 tieu chi 5 muc, quy doi tong diem 0-10, sua lich su va retention toi da 30 ngay.

### Phase 9 - Offline-first va media dung chung

Local database, content/media cache, sync queue, retry, conflict status, Google Drive upload/download, token media co han, xu ly file mo coi va quy tac xoa diem danh cu.

### Phase 10 - Admin tra cuu va ban giao

Tra cuu tai khoan, cap quyen, CMS Knowledge, media library, tra cuu Nhat ky/Plan/diem danh, dashboard co ban, Railway deployment production, seed data, build theo kha nang moi truong va huong dan ban giao. Khong co QA/UAT doc lap.

## 13. Tieu chi nghiem thu

- Phase 1 co the khoi dong PostgreSQL, API va Admin bang mot script local.
- API co health check bao gom trang thai ket noi PostgreSQL.
- Mobile co the tro vao API local qua API_BASE_URL; Admin local co the goi API qua CORS.
- App co dung 5 tab va Trang chu khong phu thuoc API.
- User co the dang ky bang email; tai khoan moi mac dinh la Thuong; xac minh email va quen mat khau hoat dong.
- Thuong hoc duoc 3 bai Co ban + 1 bai Nang cao; VIP 1 hoc duoc full Co ban + 3 bai Nang cao; VIP 2 hoc duoc full; bai khoa hien modal lien he Zalo voi Thuong/VIP 1.
- Backend tu choi truy cap bai hoc sai cap tai khoan.
- Knowledge co list bai, progress, search, bookmark, read-state, luong ly thuyet/quiz va cache offline ca text/media.
- Nhat ky co 2 subtab Intra day/Swing.
- Intra day co calendar, nhieu giao dich/ngay, form dung field moi, PNL/So R, mau lai/lo, tong ket ngay/tuan/thang.
- Swing co list don gian, form tuong tu, khong co tong ket ngay/tuan/thang va hien chien luoc hieu qua nhat.
- Plan co chu ky thang/tuan/ngay; Plan ngay cho phep chon mot hoac ca hai cap H4-M15/H1-M5; editor text/image lien mach.
- Ca nhan co profile, modal diem danh dung mot lan/ngay, 5 tieu chi voi 5 muc, tong diem thang 0-10, sua lich su va gioi han 30 ban ghi/user.
- Local notification duoc lap luc 07:00 theo gio thiet bi, khong phu thuoc backend push.
- Admin Web chay tren Railway, khong co CMS Trang chu, quan ly tai khoan/cap quyen, CMS Knowledge, media library va tra cuu du lieu user.
- File hinh di qua Railway API, luu tren Google Drive; metadata/quyen nam tren PostgreSQL.
- Offline data khong bi mat khi restart app; request loi co retry va hien trang thai sync.
