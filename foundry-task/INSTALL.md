# Foundry 安装指南

## 快速安装步骤

### 1. 手动下载 Foundry

**访问下载页面**：
https://github.com/foundry-rs/foundry/releases

**下载所需文件**：
- `forge-windows-x64.exe` → 重命名为 `forge.exe`
- `cast-windows-x64.exe` → 重命名为 `cast.exe`
- `anvil-windows-x64.exe` → 重命名为 `anvil.exe`

### 2. 设置环境

**创建目录**：
```bash
mkdir C:\foundry
```

**复制文件**：
将下载的三个 .exe 文件复制到 `C:\foundry` 目录

### 3. 添加到 PATH

**方法1：通过系统设置**
1. 按 `Win + R`，输入 `sysdm.cpl`
2. 点击"高级"选项卡
3. 点击"环境变量"
4. 在"系统变量"中找到 `Path`
5. 点击"编辑"，然后点击"新建"
6. 添加 `C:\foundry`
7. 点击所有窗口的"确定"

**方法2：通过PowerShell（管理员权限）**
```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\foundry", "Machine")
```

### 4. 验证安装

**重启 PowerShell 或 CMD**，然后运行：
```bash
forge --version
cast --version
anvil --version
```

### 5. 运行项目测试

安装完成后，在项目目录运行：
```bash
# 进入项目目录
cd E:\go\go-work\sol-task\foundry-task

# 安装依赖
forge install

# 编译合约
forge build

# 运行测试
forge test

# 运行特定测试
forge test --match-test testBasicArithmetic -vvv

# Gas报告
forge test --gas-report
```

## 备选方案：使用 Chocolatey

如果您有 Chocolatey：
```powershell
choco install foundry
```

## 备选方案：使用 Scoop

如果您有 Scoop：
```powershell
scoop install foundry
```

## 故障排除

**如果命令不识别**：
1. 确认文件已复制到 `C:\foundry`
2. 确认 `C:\foundry` 已添加到 PATH
3. 重启 PowerShell/CMD
4. 运行 `$env:PATH` 检查 PATH 是否包含 `C:\foundry`

**如果下载失败**：
1. 尝试使用 VPN 或其他网络
2. 手动从 GitHub releases 页面下载
3. 尝试不同的镜像源

安装完成后，项目就可以正常运行了！