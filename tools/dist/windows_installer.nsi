; ElephantCoding Windows installer (NSIS 3).
; Built from macOS with: makensis -D...
; The installer is per-user and does not require administrator rights.

Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"

!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "0.1.0"
!endif
!ifndef SOURCE_DIR
  !error "SOURCE_DIR is required"
!endif
!ifndef OUTPUT
  !error "OUTPUT is required"
!endif
!ifndef ICON
  !error "ICON is required"
!endif

!define PRODUCT_NAME "ElephantCoding"
!define PRODUCT_PUBLISHER "ElephantCoding contributors"
!define PRODUCT_DESCRIPTION "Nilo l'elefantino che programma"
!define PRODUCT_WEB_SITE "https://github.com/MaestroLivio/ElephantCoding"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\ElephantCoding"

Name "${PRODUCT_NAME}"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\ElephantCoding"
InstallDirRegKey HKCU "Software\ElephantCoding" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma

VIProductVersion "${PRODUCT_VERSION}.0"
VIAddVersionKey /LANG=0 "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=0 "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey /LANG=0 "FileDescription" "${PRODUCT_DESCRIPTION}"
VIAddVersionKey /LANG=0 "FileVersion" "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=0 "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=0 "LegalCopyright" "CC BY 4.0 - ElephantCoding contributors"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\ElephantCoding.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Avvia ElephantCoding"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Italian"
!insertmacro MUI_LANGUAGE "English"

Section "ElephantCoding" SEC_MAIN
  SetOutPath "$INSTDIR"
  File "${SOURCE_DIR}/ElephantCoding.exe"
  File "${SOURCE_DIR}/ElephantCoding.pck"
  SetOutPath "$INSTDIR\licenses"
  File /r "${SOURCE_DIR}/licenses/*.*"

  CreateShortCut "$SMPROGRAMS\ElephantCoding.lnk" "$INSTDIR\ElephantCoding.exe"
  CreateShortCut "$DESKTOP\ElephantCoding.lnk" "$INSTDIR\ElephantCoding.exe"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "Software\ElephantCoding" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\ElephantCoding.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1

  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" "$0"
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\ElephantCoding.lnk"
  Delete "$DESKTOP\ElephantCoding.lnk"
  Delete "$INSTDIR\ElephantCoding.exe"
  Delete "$INSTDIR\ElephantCoding.pck"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR\licenses"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  DeleteRegKey HKCU "Software\ElephantCoding"
SectionEnd
