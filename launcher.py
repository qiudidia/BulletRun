import os
import sys
import json
import shutil
import zipfile
import urllib.request
import urllib.error
import ssl

GITHUB_USER = "qiudidia"
GITHUB_REPO = "BulletRun"
GAME_EXE = "BulletRun.exe"
VERSION_FILE = "version.txt"


def get_current_version():
    if os.path.exists(VERSION_FILE):
        with open(VERSION_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    return "alpha0.0"


def extract_version_numbers(version):
    import re
    nums = re.findall(r"\d+", version)
    return [int(n) for n in nums]


def compare_versions(v1, v2):
    v1 = v1.lstrip("vV")
    v2 = v2.lstrip("vV")
    nums1 = extract_version_numbers(v1)
    nums2 = extract_version_numbers(v2)
    max_len = max(len(nums1), len(nums2))
    for i in range(max_len):
        n1 = nums1[i] if i < len(nums1) else 0
        n2 = nums2[i] if i < len(nums2) else 0
        if n1 > n2:
            return 1
        elif n1 < n2:
            return -1
    return 0


def get_latest_release():
    url = f"https://api.github.com/repos/{GITHUB_USER}/{GITHUB_REPO}/releases?per_page=1"
    headers = {
        "User-Agent": "BulletRun-Launcher/1.0",
        "Accept": "application/vnd.github+json"
    }
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    req = urllib.request.Request(url, headers=headers)
    
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=10) as response:
            data = json.loads(response.read().decode("utf-8"))
            if isinstance(data, list) and data:
                return data[0]
            elif isinstance(data, dict):
                return data
            return None
    except Exception as e:
        print(f"[错误] 获取版本信息失败: {e}")
        return None


def get_download_url(release):
    assets = release.get("assets", [])
    for asset in assets:
        name = asset.get("name", "").lower()
        if "win" in name or "windows" in name:
            return asset.get("browser_download_url", "")
    if assets:
        return assets[0].get("browser_download_url", "")
    return release.get("html_url", "")


def download_file(url, save_path):
    print(f"[下载] 正在下载: {url}")
    print(f"[下载] 保存路径: {save_path}")
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    try:
        with urllib.request.urlopen(url, context=ctx, timeout=60) as response:
            total_size = int(response.headers.get("content-length", 0))
            downloaded = 0
            chunk_size = 8192
            
            with open(save_path, "wb") as f:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        sys.stdout.write(f"\r[下载] 进度: {percent:.1f}% ({downloaded}/{total_size} bytes)")
                        sys.stdout.flush()
        
        print("\n[下载] 下载完成!")
        return True
    except Exception as e:
        print(f"\n[错误] 下载失败: {e}")
        return False


def extract_zip(zip_path, extract_dir):
    print(f"[解压] 正在解压: {zip_path}")
    print(f"[解压] 解压到: {extract_dir}")
    
    try:
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            zip_ref.extractall(extract_dir)
        print("[解压] 解压完成!")
        return True
    except Exception as e:
        print(f"[错误] 解压失败: {e}")
        return False


def run_game():
    if os.path.exists(GAME_EXE):
        print(f"[启动] 正在启动 {GAME_EXE}...")
        os.startfile(GAME_EXE)
    else:
        print(f"[错误] 未找到 {GAME_EXE}，请先下载游戏")
        input("按回车键退出...")


def main():
    print("=" * 50)
    print("      Bullet Run 启动器")
    print("=" * 50)
    
    current_version = get_current_version()
    print(f"[版本] 当前版本: {current_version}")
    
    print("[检查] 正在检查更新...")
    release = get_latest_release()
    
    if not release:
        print("[检查] 无法获取最新版本信息，直接启动游戏")
        run_game()
        return
    
    latest_version = release.get("tag_name", "")
    
    if not latest_version:
        print("[检查] 未找到版本信息，直接启动游戏")
        run_game()
        return
    
    print(f"[检查] 最新版本: {latest_version}")
    
    compare_result = compare_versions(latest_version, current_version)
    
    if compare_result > 0:
        print(f"[更新] 发现新版本: {latest_version}")
        changelog = release.get("body", "")
        if changelog:
            print("[更新] 更新内容:")
            print(changelog[:500] + ("..." if len(changelog) > 500 else ""))
        
        download_url = get_download_url(release)
        if not download_url:
            print("[错误] 未找到下载链接")
            run_game()
            return
        
        print(f"[更新] 下载链接: {download_url}")
        
        choice = input("[更新] 是否下载更新? (Y/N): ").strip().upper()
        if choice == "Y":
            zip_name = f"BulletRun-{latest_version}.zip"
            zip_path = os.path.join(os.getcwd(), zip_name)
            
            if download_file(download_url, zip_path):
                if extract_zip(zip_path, os.getcwd()):
                    print("[更新] 更新完成!")
                    with open(VERSION_FILE, "w", encoding="utf-8") as f:
                        f.write(latest_version)
                    os.remove(zip_path)
                else:
                    print("[更新] 解压失败，尝试直接启动")
            else:
                print("[更新] 下载失败，尝试直接启动")
        else:
            print("[更新] 跳过更新")
    elif compare_result == 0:
        print("[检查] 当前已是最新版本")
    else:
        print(f"[检查] 当前版本({current_version})高于最新版本({latest_version})")
    
    run_game()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[退出] 用户中断")
    except Exception as e:
        print(f"[错误] 启动器运行出错: {e}")
        input("按回车键退出...")