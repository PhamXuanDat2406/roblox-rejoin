Được. Vì m không copy được đoạn code dài, mình đã tạo sẵn file để m chỉ việc tải xuống → upload GitHub → Termux tải về.

Tải 2 file này về điện thoại trước:

rejoin.sh — tool chính
install.sh — file cài đặt
1. Tạo repo GitHub

Vào GitHub → New repository → đặt ví dụ:

roblox-rejoin

Chọn Public cho dễ tải bằng Termux, rồi Create repository.

2. Upload file

Trong repo:

Add file → Upload files

Upload:

rejoin.sh
install.sh

rồi Commit changes.

3. Sửa install.sh

Mở install.sh trên GitHub → Edit ✏️.

Tìm dòng:

REPO_RAW_BASE="__REPLACE_RAW_BASE__"

Đổi thành:

REPO_RAW_BASE="https://raw.githubusercontent.com/TEN_GITHUB/roblox-rejoin/main"

Ví dụ GitHub là abc123:

REPO_RAW_BASE="https://raw.githubusercontent.com/abc123/roblox-rejoin/main"

Commit lại.

4. Cài trên Termux

Lúc này trên điện thoại chỉ cần nhập một dòng ngắn:

curl -fsSL https://raw.githubusercontent.com/TEN_GITHUB/roblox-rejoin/main/install.sh | bash

Ví dụ:

curl -fsSL https://raw.githubusercontent.com/abc123/roblox-rejoin/main/install.sh | bash

Nó sẽ tự:

Cài package cần thiết
      ↓
Tải rejoin.sh từ GitHub
      ↓
Lưu vào ~/roblox-rejoin/
      ↓
chmod +x
      ↓
Tạo lệnh rejoin
      ↓
Mở tool

Sau này không cần chạy link GitHub nữa, chỉ mở Termux và gõ:

rejoin

Menu sẽ hiện:

╔════════════════════════════════════════╗
║      ROBLOX MULTI REJOIN - TERMUX      ║
╠════════════════════════════════════════╣
║ PlaceId : 1730877806                   ║
║ Clients : 5                            ║
╠════════════════════════════════════════╣
║ [1] REJOIN ALL CLIENTS                 ║
║ [2] AUTO REJOIN ALL                    ║
║ [3] SHOW DETECTED CLIENTS              ║
║ [4] SET PLACE ID                       ║
║ [0] EXIT                               ║
╚════════════════════════════════════════╝

Quan trọng: trước tiên bấm [3] xem nó có nhận đủ com.roblox.client, clientb, clientc... hay không. Nếu nhận đủ thì bấm [1] là rejoin toàn bộ trong một lần.

Nếu m kết nối GitHub qua plugin mình vừa gợi ý, mình cũng có thể hỗ trợ làm việc với repo trực tiếp thay vì m phải upload thủ công.

rejoin.sh
Code
install.sh
Code
cái này bị gì

Thấy rồi. Máy m có file thư viện LZ4, nhưng thiếu đúng tên mà apt đang tìm là:

liblz4.so.1

Trong ảnh file hiện có vẻ là:

$PREFIX/lib/liblz4.so2025

và thư mục cache apt/archives cũng chưa tồn tại. Lỗi apt thiếu liblz4.so.1 này cũng đã được người dùng Termux báo lại trước đây.

Thử sửa symlink trước, cách này dễ hoàn tác. Chạy:

ln -s "$PREFIX/lib/liblz4.so2025" "$PREFIX/lib/liblz4.so.1"

Sau đó kiểm tra:

ls -l $PREFIX/lib/liblz4*

Nếu ổn, m phải thấy đại loại:

liblz4.so.1 -> /data/data/com.termux/files/usr/lib/liblz4.so2025

Rồi test:

apt --version
Nếu apt --version chạy được

Chạy tiếp:

dpkg --configure -a

rồi:

apt --fix-broken install -y

và cuối cùng:

pkg upgrade -y

Sau đó mới quay lại cài tool Roblox.

Nếu lệnh ln báo file không tồn tại

Thì đừng đoán tên file, chạy:

ls -lb $PREFIX/lib/ | grep lz4

chụp kết quả gửi mình. Mình sẽ viết đúng lệnh theo tên file thật của máy m.

Ổn rồi. Giờ làm tiếp theo thứ tự này để sửa package cho sạch rồi cài tool.

Trước hết chạy:

dpkg --configure -a
apt --fix-broken install -y
pkg update -y
pkg upgrade -y

Sau đó cài mấy gói tool cần:

pkg install bash coreutils grep sed inetutils curl -y

Nếu repo GitHub của m vẫn là roblox-rejoin và username là PhamXuanDat2406, chạy:

curl -fsSL https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main/install_clien.sh | bash

Cài xong, mở tool bằng:

rejoin

Rồi trong menu bấm [3] SHOW DETECTED CLIENS trước. Nó cần hiện kiểu:

com.roblox.clien
com.roblox.cliena
com.roblox.clienb
com.roblox.clienc

Nếu thấy đủ thì bấm [1] REJOIN ALL CLIENS.

Nếu lệnh curl báo 404, gửi mình link repo GitHub của m, mình ghép đúng lệnh cài cho m.

sao k đc

Bị 404 vì tên file trên GitHub không khớp đó ní 😄

Trong repo của m hiện chỉ có:

install.sh
rejoin.sh

Nhưng m lại chạy:

.../install_clien.sh

nên GitHub báo 404.

Giờ trong Termux chạy đúng lệnh này:

curl -fsSL https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main/install.sh | bash

Nhưng còn một chỗ quan trọng: mở install.sh trên GitHub và kiểm tra dòng:

REPO_RAW_BASE=

nó phải là:

REPO_RAW_BASE="https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main"

Và vì file tool trong repo của m tên là rejoin.sh, đoạn tải trong install.sh phải là:

curl -fsSL \
"$REPO_RAW_BASE/rejoin.sh" \
-o "$TOOL_DIR/rejoin.sh"

Tóm lại repo m giữ đúng như ảnh là được:

roblox-rejoin/
├── install.sh
└── rejoin.sh

Sau đó chạy:

curl -fsSL https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main/install.sh | bash

Cài xong thử:

rejoin

Nếu muốn, m chụp hoặc copy nội dung file install.sh hiện tại lên đây, mình kiểm tra giúp để chắc chắn nó không còn trỏ nhầm rejoin_clien.sh.

ra như này nhưng mà nó nháy liên tục

Đúng lỗi rồi. Có 2 chuyện:

Nháy liên tục vì installer tự mở tool ngay khi chạy qua curl | bash, nên menu không đọc được bàn phím đúng cách.
Ảnh của m hiện Clients, tức repo đang còn bản cũ client*, chưa phải clien*.

Mình đã sửa cả hai. Tải 2 file mới:

rejoin_fixed.sh
install_fixed.sh

Trên GitHub repo của m, thay nội dung như này:

rejoin.sh  <- upload file rejoin_fixed.sh nhưng đổi tên thành rejoin.sh
install.sh <- upload file install_fixed.sh nhưng đổi tên thành install.sh

Sau đó trong Termux, nếu nó đang nháy thì bấm:

CTRL + C

Rồi cài lại:

curl -fsSL https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main/install.sh | bash

Bản mới sẽ không tự mở menu nữa. Khi nó báo cài xong, chạy:

source ~/.bashrc
rejoin

Menu đúng phải hiện:

Cliens : ...
[1] REJOIN ALL CLIENS
[3] SHOW DETECTED CLIENS

Đầu tiên bấm:

3

để xem nó có tìm ra:

com.roblox.clien
com.roblox.cliena
com.roblox.clienb
...

Nếu vẫn hiện Cliens : 0, chạy:

pm list packages | grep -i roblox

rồi gửi ảnh kết quả, mình sẽ chỉnh đúng pattern package theo máy m. 

rejoin_fixed.sh
Code
install_fixed.sh
Code

Thư viện
/
install_fixed.sh
99
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
#!/data/data/com.termux/files/usr/bin/bash
set -e


REPO_RAW_BASE="https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main"
TOOL_DIR="$HOME/roblox-rejoin"


echo "======================================"
echo "   ROBLOX MULTI REJOIN INSTALLER"
echo "======================================"
echo


pkg update -y
pkg install bash coreutils grep sed inetutils curl -y


mkdir -p "$TOOL_DIR"


echo "[+] Dang tai rejoin.sh..."
curl -fsSL "$REPO_RAW_BASE/rejoin.sh" -o "$TOOL_DIR/rejoin.sh"


chmod +x "$TOOL_DIR/rejoin.sh"


grep -qxF 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' "$HOME/.bashrc" 2>/dev/null || \
echo 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' >> "$HOME/.bashrc"


echo
echo "======================================"
echo "[OK] CAI DAT XONG"
echo "======================================"
echo
echo "QUAN TRONG:"
echo "Installer se KHONG tu mo menu de tranh loi nhay."
echo
echo "Sau khi installer ket thuc, chay:"
echo
echo "  source ~/.bashrc"
echo "  rejoin"
echo

