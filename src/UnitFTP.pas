unit UnitFTP;

interface

uses IdFTP, System.SysUtils, IdComponent, IdFTPList,
	System.Generics.Collections, IdAllFTPListParsers, System.Classes;

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
//		function SetProgressBar(Value: TProgressBar): iFTP;
    function Conecta: iFTP;
    function Desconecta: iFTP;
    function Execute(Tentativa: smallint = 0): iFTP;
    function SetOnMostrarLog(Value: TOnMostrarLog): iFTP;
		function ListaArquivos: iFTP;
		function ApagaArquivosAntigos(Extensao: string; PrazoDias: integer): iFTP;
		function RetornaArquivosRecentes(Extensao: string; PrazoDias: integer; var Retorno: TStringList): iFTP;
		function AcessaDiretorio(Caminho: string): iFTP;
		function RetornaListaArquivos(Extensao: string; var Retorno: TList<TIdFTPListItem>): iFTP;
		function BaixaArquivo(ArquivoOrigem, ArquivoDestino: string; Sobrescrever: boolean): iFTP;
		function GetListaArquivos: TList<string>;
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
//    FProgressBar: TProgressBar;
		FListaArquivos: TList<TIdFTPListItem>;
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
    function Conecta: iFTP;
    function Desconecta: iFTP;
    function Execute(Tentativa: smallint = 0): iFTP;
    function SetOnMostrarLog(Value: TOnMostrarLog): iFTP;
//    function SetProgressBar(Value: TProgressBar): iFTP;
    function ListaArquivos: iFTP;
    function ApagaArquivosAntigos(Extensao: string; PrazoDias: integer): iFTP;
    function RetornaArquivosRecentes(Extensao: string; PrazoDias: integer; var Retorno: TStringList): iFTP;
    function AcessaDiretorio(Caminho: string): iFTP;
    function RetornaListaArquivos(Extensao: string; var Retorno: TList<TIdFTPListItem>): iFTP;
		function BaixaArquivo(ArquivoOrigem, ArquivoDestino: string; Sobrescrever: boolean): iFTP;
		function GetListaArquivos: TList<string>;
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
  System.DateUtils;

{ TFTP }

function TPortalFTP.ApagaArquivosAntigos(Extensao: string; PrazoDias: integer): iFTP;
var ArquivoFTP: TIdFTPListItem;
begin
  Conecta;
  ListaArquivos;
	for ArquivoFTP in FListaArquivos do
  begin
    if (ExtractFileExt(ArquivoFTP.FileName) = Extensao) and (DaysBetween(Now, ArquivoFTP.ModifiedDate) > PrazoDias) then
      IdFTP.Delete(ArquivoFTP.FileName);
  end;
end;

function TPortalFTP.BaixaArquivo(ArquivoOrigem, ArquivoDestino: string; Sobrescrever: boolean): iFTP;
begin
  Result := Self;
  Conecta;
  TamanhoArquivo := IdFTP.Size(ArquivoOrigem);
  DownloadCompleto := False;
  IdFTP.Get(ArquivoOrigem, ArquivoDestino, Sobrescrever);
end;

function TPortalFTP.Conecta: iFTP;
begin
  if not IdFTP.Connected then
  begin
    IdFTP.Host     := FHost;
    IdFTP.Port     := FPort;
    IdFTP.Username := FUserName;
    IdFTP.Password := FPassword;
    IdFTP.Passive  := FModoPassivo; { usa modo passivo }
    if Assigned(OnOuvirLog) then
    begin
      OnOuvirLog('');
      OnOuvirLog('Conectando ao FTP...');
    end;
    IdFTP.Connect;
    if Assigned(OnOuvirLog) then
    begin
      OnOuvirLog('Conectado com sucesso!');
    end;
    AcessaDiretorio(FPastaDestino);
  end;
end;

constructor TPortalFTP.Create;
begin
  IdFTP             := TIdFTP.Create(nil);
  IdFTP.OnWork      := OnIdFTPWork;
  IdFTP.OnWorkBegin := OnIdFTPWorkBegin;
  IdFTP.OnWorkEnd   := OnIdFTPWorkEnd;
  FPort             := 21;
  FModoPassivo      := True;
  FListaArquivos    := TList<TIdFTPListItem>.Create;
end;

function TPortalFTP.AcessaDiretorio(Caminho: string): iFTP;
var Pastas: TArray<string>;
  i: Integer;
begin
  Pastas := Caminho.Split(['/']);
  for i := Low(Pastas) to High(Pastas) do
  begin
    if not FTPArquivoExiste(IdFTP, Pastas[i]) then
    begin
      if Assigned(OnOuvirLog) then
      begin
        OnOuvirLog('');
        OnOuvirLog('Criando o Diretório ' + Pastas[i] + '...');
      end;
      try
        IdFTP.MakeDir(Pastas[i]);
      except
      end;
      if Assigned(OnOuvirLog) then
      begin
        OnOuvirLog('Diretório criado com sucesso!');
      end;
    end;
    IdFTP.ChangeDir(Pastas[i]);
  end;
end;

function TPortalFTP.Desconecta: iFTP;
begin
  if IdFTP.Connected then
    IdFTP.Disconnect;
end;

destructor TPortalFTP.Destroy;
begin
  IdFTP.DisposeOf;
  FListaArquivos.DisposeOf;
  inherited;
end;

function TPortalFTP.Execute(Tentativa: smallint = 0): iFTP;
var
  Pastas: TArray<string>;
  i: Integer;
begin
  try
    Conecta;
    try
      TamanhoArquivo := TamanhoDoArquivo(FArqOrigem);
      DownloadCompleto := False;
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
      begin
        if Assigned(OnOuvirLog) then
        begin
          OnOuvirLog('Houve erro ao enviar o arquivo'#13#10 + E.Message);
        end;
        if (Pos('Read timed out', E.Message) > 0) and (Tentativa < 3) then
        begin
          if Assigned(OnOuvirLog) then
          begin
            OnOuvirLog('');
            OnOuvirLog('Fazendo nova tentativa de envio...');
            Sleep(1000);
          end;
          Desconecta;
          Execute(Tentativa + 1);
        end;
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
    CompFTP.List(nil, '', False);
    Result := (CompFTP.ListResult.IndexOf(ArquivoOuDiretorio) >= 0);
  except
    Result := False;
  end;
end;

function TPortalFTP.GetListaArquivos: TList<string>;
var
	Arq: TIdFTPListItem;
begin
	Result := TList<String>.Create;
	for Arq in FListaArquivos do
	begin
	  Result.Add(Arq.FileName);	
	end;
end;

function TPortalFTP.ListaArquivos: iFTP;
var
  i: Integer;
begin
  Conecta;
  if IdFTP.Connected then
  begin
    //IdFTP.ChangeDir(FPastaDestino);
    FListaArquivos.Clear;
    //IdFTP.UseMLIS := False;
    IdFTP.List;
    for i := 0 to IdFTP.DirectoryListing.Count-1 do
      FListaArquivos.Add(IdFTP.DirectoryListing.Items[i]);
  end;
end;

procedure TPortalFTP.OnIdFTPWork(Sender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
begin
  if (AWorkCount = 0) or (TamanhoArquivo = 0) or (DownloadCompleto) then
    Exit;
//	if Assigned(FProgressBar) then
//	begin
//		TThread.Synchronize(TThread.CurrentThread,
//		procedure
//		begin
//			FProgressBar.Position := Round(AWorkCount / TamanhoArquivo * 100);
//		end);
//  end;
  if SecondsBetween(Time, HoraParcial) < 1 then
  begin
    DownloadCompleto  := AWorkCount >= TamanhoArquivo;
    DiferencaDownload := AWorkCount;
    HoraParcial       := Time;
    Exit;
  end;
  if Assigned(OnOuvirLog) then
  begin
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
    if Assigned(OnOuvirLog) then
    begin
      KBytesPorSegundo := (TamanhoArquivo / 1024) / ((MinutosTranscorridos * 60) + SegundosTranscorridos);
      OnOuvirLog(FormatFloat(',0', TamanhoArquivo) + ' bytes enviados em ' + IntToStr(MinutosTranscorridos) + 'm ' + IntToStr(SegundosTranscorridos) + 's.' + '  Média de ' + FormatFloat(',0.00', KBytesPorSegundo) + ' KB/s.');
    end;
  end;
//  if Assigned(FProgressBar) then
//    FProgressBar.Visible := False;
end;

function TPortalFTP.RetornaArquivosRecentes(Extensao: string; PrazoDias: integer; var Retorno: TStringList): iFTP;
var ArquivoFTP: TIdFTPListItem;
begin
  Conecta;
  ListaArquivos;
  if not Assigned(Retorno) then
    Retorno := TStringList.Create;
  Retorno.Clear;
  for ArquivoFTP in FListaArquivos do
  begin
    if (ExtractFileExt(ArquivoFTP.FileName) = Extensao) and (DaysBetween(Now, ArquivoFTP.ModifiedDate) <= PrazoDias) then
      Retorno.Add(ArquivoFTP.FileName);
  end;
end;

function TPortalFTP.RetornaListaArquivos(Extensao: string; var Retorno: TList<TIdFTPListItem>): iFTP;
var ArquivoFTP: TIdFTPListItem;
begin
  Result := Self;
  Conecta;
  ListaArquivos;
  if not Assigned(Retorno) then
    Retorno := TList<TIdFTPListItem>.Create;
  Retorno.Clear;
  for ArquivoFTP in FListaArquivos do
  begin
    if (ExtractFileExt(ArquivoFTP.FileName) = Extensao) then
      Retorno.Add(ArquivoFTP);
  end;
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
//
//function TPortalFTP.SetProgressBar(Value: TProgressBar): iFTP;
//begin
//	Result       := Self;
//	FProgressBar := Value;
//end;

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
