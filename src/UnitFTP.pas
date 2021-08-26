unit UnitFTP;

interface

uses IdFTP, System.SysUtils, IdComponent, Vcl.ComCtrls;

type
  TOnMostrarLog = reference to procedure(Value: string);

  iFTP = interface
    ['{2BB3EE21-FDE7-41AD-89CE-BFA70E3969B8}']
    function SetHost(Value: string): iFTP;
    function SetPort(Value: integer): iFTP;
    function SetUserName(Value: string): iFTP;
    function SetPassword(Value: string): iFTP;
    function SetModoPassivo(Value: Boolean): iFTP;
    function SetArqOrigem(Value: string): iFTP;
    function SetPastaDestino(Value: string): iFTP;
    function SetArqDestino(Value: string): iFTP;
    function SetProgressBar(Value: TProgressBar): iFTP;
    function Execute: iFTP;
    function SetOnMostrarLog(Value: TOnMostrarLog): iFTP;
  end;

  TPortalFTP = class(TInterfacedObject, iFTP)
  private
    FHost: string;
    FPort: integer;
    FUserName: string;
    FPassword: string;
    FModoPassivo: Boolean;
    FArqOrigem: string;
    FPastaDestino: string;
    FArqDestino: string;
    IdFTP: TIdFTP;
    OnOuvirLog: TOnMostrarLog;
    FProgressBar: TProgressBar;
    function FTPArquivoExiste(CompFTP: TIdFTP; ArquivoOuDiretorio: string): Boolean;
    function TamanhoDoArquivo(Arquivo: string): integer;
    procedure OnIdFTPWork(Sender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
    procedure OnIdFTPWorkBegin(Sender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
    procedure OnIdFTPWorkEnd(Sender: TObject; AWorkMode: TWorkMode);
  public
    constructor Create;
    destructor Destroy; override;
    class function New: iFTP;
    function SetHost(Value: string): iFTP;
    function SetPort(Value: integer): iFTP;
    function SetUserName(Value: string): iFTP;
    function SetPassword(Value: string): iFTP;
    function SetModoPassivo(Value: Boolean): iFTP;
    function SetArqOrigem(Value: string): iFTP;
    function SetPastaDestino(Value: string): iFTP;
    function SetArqDestino(Value: string): iFTP;
    function Execute: iFTP;
    function SetOnMostrarLog(Value: TOnMostrarLog): iFTP;
    function SetProgressBar(Value: TProgressBar): iFTP;
  end;

var
  DownloadCompleto: Boolean;
  ExecutandoBackup: Boolean;
  DiferencaDownload: integer;
  KBytesPorSegundo: Extended;
  HoraParcial: TTime;
  HoraInicio: TDateTime;
  UnidadePorSegundo: string;
  TamanhoArquivo: Int64;

implementation

uses
  System.Classes, System.DateUtils;

{ TFTP }

constructor TPortalFTP.Create;
begin
  IdFTP             := TIdFTP.Create(nil);
  IdFTP.OnWork      := OnIdFTPWork;
  IdFTP.OnWorkBegin := OnIdFTPWorkBegin;
  IdFTP.OnWorkEnd   := OnIdFTPWorkEnd;
  FPort             := 21;
  FModoPassivo      := True;
end;

destructor TPortalFTP.Destroy;
begin
  IdFTP.DisposeOf;
  inherited;
end;

function TPortalFTP.Execute: iFTP;
begin
  IdFTP.Disconnect();
  IdFTP.Host     := FHost;
  IdFTP.Port     := FPort;
  IdFTP.Username := FUserName;
  IdFTP.Password := FPassword;
  IdFTP.Passive  := True; { usa modo passivo }
  // IdFTPBackup.RecvBufferSize := 8192;
  try
    if Assigned(OnOuvirLog) then
    begin
      OnOuvirLog('');
      OnOuvirLog('Conectando ao FTP...');
    end;
    { Espera até 10 segundos pela conexão }
    IdFTP.Connect;
    if Assigned(OnOuvirLog) then
    begin
      OnOuvirLog('Conectado com sucesso!');
    end;
    try
      IdFTP.ChangeDir(FPastaDestino);
      if not FTPArquivoExiste(IdFTP, FPastaDestino) then
      begin
        if Assigned(OnOuvirLog) then
        begin
          OnOuvirLog('');
          OnOuvirLog('Criando o Diretório ' + FPastaDestino + '...');
        end;
        try
          IdFTP.MakeDir(FPastaDestino);
        except
        end;
        if Assigned(OnOuvirLog) then
        begin
          OnOuvirLog('Diretório criado com sucesso!');
        end;
      end;
      IdFTP.ChangeDir(FPastaDestino);
      TamanhoArquivo := TamanhoDoArquivo(FArqOrigem);
      if Assigned(OnOuvirLog) then
      begin
        OnOuvirLog('');
        OnOuvirLog('Enviando o arquivo de backup: ' + FormatFloat(',0', TamanhoArquivo) + ' Bytes | ' + FormatFloat(',0.00', TamanhoArquivo / 1024) + ' KBytes | ' + FormatFloat(',0.00', TamanhoArquivo / 1048576) + ' MBytes.');
        OnOuvirLog('Início do envio: ' + FormatDateTime('dd/mm/yyyy "às" hh:nn:ss.', Now));
        OnOuvirLog('--');
      end;
      IdFTP.Put(FArqOrigem, FArqDestino, False);
      if Assigned(OnOuvirLog) then
      begin
        OnOuvirLog('Arquivo enviado com sucesso!');
      end;
    except
      on E: Exception do
        if Assigned(OnOuvirLog) then
        begin
          OnOuvirLog('Houve erro ao enviar o arquivo'#13#10 + E.Message);
        end;
    end;
  except
    on E: Exception do
      if Assigned(OnOuvirLog) then
      begin
        OnOuvirLog('Houve erro ao conectar ao servidor FTP'#13#10 + E.Message);
      end;
  end;
  if IdFTP.Connected then
    IdFTP.Disconnect;
end;

function TPortalFTP.FTPArquivoExiste(CompFTP: TIdFTP; ArquivoOuDiretorio: string): Boolean;
begin
  try
    CompFTP.List(nil, ArquivoOuDiretorio, False);
    Result := (CompFTP.ListResult.Count > 0);
  except
    Result := False;
  end;
end;

procedure TPortalFTP.OnIdFTPWork(Sender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
begin
  if (AWorkCount = 0) or (TamanhoArquivo = 0) then
    Exit;
  if Assigned(FProgressBar) then
    FProgressBar.Position := Round(AWorkCount / TamanhoArquivo * 100);
  try
    KBytesPorSegundo := ((AWorkCount - DiferencaDownload) / 1024) / (MilliSecondsBetween(Time, HoraParcial) / 1000);
    if KBytesPorSegundo < 1024 then
    begin
      UnidadePorSegundo := 'KB/s';
    end
    else
    begin
      KBytesPorSegundo  := KBytesPorSegundo / 1024; // Converto para Mega Bytes por segundo
      UnidadePorSegundo := 'MB/s';
    end;
  except
    KBytesPorSegundo  := 0;
    UnidadePorSegundo := '--';
  end;
  if Assigned(OnOuvirLog) then
  begin
    if AWorkCount < 1024 then
      OnOuvirLog(Format('Transferido %1d Bytes de %1d Bytes  (%1.2n%%) (%1d %s)', [AWorkCount, TamanhoArquivo, AWorkCount / TamanhoArquivo * 100, Round(KBytesPorSegundo), UnidadePorSegundo]));
    if (AWorkCount >= 1024) and (AWorkCount < 1048576) then
      OnOuvirLog(Format('Transferido %1.2n KBytes de %1.2n KBytes  (%1.2n%%) (%1d %s)', [AWorkCount / 1024, TamanhoArquivo / 1024, AWorkCount / TamanhoArquivo * 100, Round(KBytesPorSegundo), UnidadePorSegundo]));
    if (AWorkCount >= 1048576) then
      OnOuvirLog(Format('Transferido %1.2n MBytes de %1.2n MBytes  (%1.2n%%) (%1d %s)', [AWorkCount / 1048576, TamanhoArquivo / 1048576, AWorkCount / TamanhoArquivo * 100, Round(KBytesPorSegundo), UnidadePorSegundo]));
  end;
  DownloadCompleto  := AWorkCount >= TamanhoArquivo;
  DiferencaDownload := AWorkCount;
  HoraParcial       := Time;
end;

procedure TPortalFTP.OnIdFTPWorkBegin(Sender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
begin
  HoraInicio        := Now;
  HoraParcial       := Time;
  DiferencaDownload := 0;
  DownloadCompleto  := False;
end;

procedure TPortalFTP.OnIdFTPWorkEnd(Sender: TObject; AWorkMode: TWorkMode);
var
  MinutosTranscorridos, SegundosTranscorridos: Int64;
begin
  if DownloadCompleto then
  begin
    SegundosTranscorridos := SecondsBetween(Now, HoraInicio);
    MinutosTranscorridos  := 0;
    while SegundosTranscorridos > 59 do
    begin
      Inc(MinutosTranscorridos, 1);
      Dec(SegundosTranscorridos, 60);
    end;
    if Assigned(OnOuvirLog) then
    begin
      OnOuvirLog('Transferência completa em ' + FormatDateTime('dd/mm/yyyy "às" hh:nn:ss!', Now));
    end;
    KBytesPorSegundo := (TamanhoArquivo / 1024) / ((MinutosTranscorridos * 60) + SegundosTranscorridos);
    if Assigned(OnOuvirLog) then
    begin
      OnOuvirLog(FormatFloat(',0', TamanhoArquivo) + ' bytes enviados em ' + IntToStr(MinutosTranscorridos) + 'm ' + IntToStr(SegundosTranscorridos) + 's.' + '  Média de ' + FormatFloat(',0.00', KBytesPorSegundo) + ' KB/s.');
    end;
  end;
  if Assigned(FProgressBar) then
    FProgressBar.Visible := False;
end;

class function TPortalFTP.New: iFTP;
begin
  Result := Self.Create;
end;

function TPortalFTP.SetOnMostrarLog(Value: TOnMostrarLog): iFTP;
begin
  Result     := Self;
  OnOuvirLog := Value;
end;

function TPortalFTP.SetArqDestino(Value: string): iFTP;
begin
  Result      := Self;
  FArqDestino := Value;
end;

function TPortalFTP.SetArqOrigem(Value: string): iFTP;
begin
  Result     := Self;
  FArqOrigem := Value;
end;

function TPortalFTP.SetHost(Value: string): iFTP;
begin
  Result := Self;
  FHost  := Value;
end;

function TPortalFTP.SetModoPassivo(Value: Boolean): iFTP;
begin
  Result       := Self;
  FModoPassivo := Value;
end;

function TPortalFTP.SetPassword(Value: string): iFTP;
begin
  Result    := Self;
  FPassword := Value;
end;

function TPortalFTP.SetPastaDestino(Value: string): iFTP;
begin
  Result        := Self;
  FPastaDestino := Value;
end;

function TPortalFTP.SetPort(Value: integer): iFTP;
begin
  Result := Self;
  FPort  := Value;
end;

function TPortalFTP.SetProgressBar(Value: TProgressBar): iFTP;
begin
  Result       := Self;
  FProgressBar := Value;
end;

function TPortalFTP.SetUserName(Value: string): iFTP;
begin
  Result    := Self;
  FUserName := Value;
end;

function TPortalFTP.TamanhoDoArquivo(Arquivo: string): integer;
var
  FileStream: TFileStream;
begin
  FileStream := TFileStream.Create(Arquivo, fmOpenRead or fmShareExclusive);
  try
    Result := FileStream.Size;
  finally
    FileStream.Free;
  end;
end;

end.
