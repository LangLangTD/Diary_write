; 日记本 Windows 安装程序
; 编译：ISCC.exe diary.iss
; 输出：dist\Diary-win-v1.0.0-setup.exe

#define AppName "日记本"
#define AppNameEn "Diary"
#define AppVersion "1.0.0"
#define AppPublisher "Personal"
#define AppExeName "date_write.exe"

[Setup]
AppId={{7C3E9A41-5B82-4D6F-9E13-2A8D5F60B7C4}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\{#AppNameEn}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=no
OutputDir=..\dist
OutputBaseFilename=Diary-win-v{#AppVersion}-setup
SetupIconFile=diary.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; 不需要管理员：装到当前用户目录，避免每次安装弹 UAC
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "chinese"; MessagesFile: "compiler:Default.isl"

[Messages]
chinese.WelcomeLabel1=欢迎安装 [name]
chinese.WelcomeLabel2=即将在 [name/ver] 上安装 [name/ver]。%n%n这个程序是个人日记本，数据只保存在你自己的电脑上。%n%n如果之前安装过旧版本，建议先到「我的 → 导出日记」导出一份备份再继续。
chinese.SelectDirLabel3=安装程序将把 [name/ver] 安装到以下文件夹。%n%n点击「下一步」继续。
chinese.SelectDirBrowseLabel=点击「浏览」选择其它文件夹。
chinese.ReadyLabel1=准备开始安装 [name/ver]。
chinese.FinishedHeadingLabel=安装 [name/ver] 完成
chinese.FinishedLabel=已完成安装。%n%n要不要现在就打开日记本？
chinese.ClickFinish=要现在运行 [name] 吗？
chinese.ExitSetupMessage=要退出安装程序吗？
chinese.UninstallConfirmTitle=卸载日记本
chinese.UninstallConfirm=确定要卸载日记本吗？%n%n注意：你写的日记不会删除，它们仍然保存在%1。%n%n如果想在卸载前删掉日记，请先手动删除那个文件夹。
chinese.SelectLanguage=选择语言

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"; Flags: checkedonce

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
Name: "{group}\卸载 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "立即运行 {#AppName}"; Flags: nowait postinstall skipifsilent