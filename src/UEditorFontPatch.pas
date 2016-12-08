unit UEditorFontPatch;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Rtti;

procedure Register;

implementation

var
  FTarget: Pointer;
  FOrgCodes: array[0..4] of Byte;
  FFixedPitchFonts: ^TStringList;

function NewFindFixedPitchFonts: TStringList;

  function EnumFontsProc(lplf: PLogFont; lptm: PTextMetric; dwType: DWORD;
    lpData: LPARAM): Integer; stdcall;
  begin
    Result := 1;
    if lplf^.lfFaceName[0] = '@' then Exit;
    TStringList(lpData).Add(lplf^.lfFaceName);
  end;

var
  DC: HDC;
begin
  DC := CreateCompatibleDC(0);
  try
    Result := TStringList.Create;
    EnumFonts(DC, nil, @EnumFontsProc, LPARAM(Result));
    Result.Sorted := True;

    if Result.Count = 0 then
      raise Exception.Create('No fonts available for editor');
  finally
    DeleteDC(DC);
  end;
end;

procedure Register;

  function GetCoreIdeFileName: string;
  var
    ctx: TRttiContext;
  begin
    Result := ctx.FindType('EditorControl.TEditControl').Package.Name;
  end;

var
  coreIdeFileName: string;
  hModule: THandle;
  oldProtect: DWORD;
begin
  coreIdeFileName := GetCoreIdeFileName;
  if not FileExists(coreIdeFileName) then Exit;
  hModule := GetModuleHandle(PChar(coreIdeFileName));

  FFixedPitchFonts := GetProcAddress(hModule, '@Vedopts@FixedPitchFonts');
  if FFixedPitchFonts = nil then Exit;
  if FFixedPitchFonts^ <> nil then
    FreeAndNil(FFixedPitchFonts^);
  FFixedPitchFonts^ := NewFindFixedPitchFonts;

  FTarget := GetProcAddress(hModule, '@Envoptions@FindFixedPitchFonts$qqrv');
  if FTarget = nil then Exit;
  VirtualProtect(FTarget, 5, PAGE_READWRITE, oldProtect);
  Move(FTarget^, FOrgCodes, 5);
  PByte(FTarget)^ := $E9;
  PNativeInt(PByte(FTarget) + 1)^ := NativeInt(@NewFindFixedPitchFonts) - (NativeInt(FTarget) + 5);
  VirtualProtect(FTarget, 5, oldProtect, nil);
  FlushInstructionCache(GetCurrentProcess, FTarget, 5);
end;

procedure Unregister;
type
  TFunction = function: TStringList;
var
  oldProtect: DWORD;
begin
  if FTarget = nil then Exit;
  VirtualProtect(FTarget, 5, PAGE_READWRITE, oldProtect);
  Move(FOrgCodes, FTarget^, 5);
  VirtualProtect(FTarget, 5, oldProtect, nil);
  FlushInstructionCache(GetCurrentProcess, FTarget, 5);

  if FFixedPitchFonts = nil then Exit;
  if FFixedPitchFonts^ = nil then Exit;
  FreeAndNil(FFixedPitchFonts^);
  FFixedPitchFonts^ := TFunction(FTarget)();
end;

initialization
finalization
  Unregister;
end.