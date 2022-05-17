# Portal-FTP

## USAGE

```delphi
uses
  UnitFTP;

var
  FTPTest: iFTP;
begin
  try
    FTPTest := TPortalFTP.New;
    FTPTest.SetHost('fpt.host.com.br');
    FTPTest.SetUserName('user');
    FTPTest.SetPassword('password');
    FTPTest.SetArqOrigem('file_orig');
    FTPTest.SetArqDestino('file_dest');
    FTPTest.SetPastaDestino('path_dest');
    FTPTest.SetOnMostrarLog(ShowLog);//event log listening
    TThread.CreateAnonymousThread(
      procedure
      begin
        FTPTest.Execute;
      end).Start;
  except
    on E: Exception do
      raise Exception.Create('Erro ' + E.Message);
  end;

```

## Example Log Listening

```delphi

procedure TForm1.ShowLog(Value: string);
begin
  Memo1.Lines.Add(Value);
end;

```
