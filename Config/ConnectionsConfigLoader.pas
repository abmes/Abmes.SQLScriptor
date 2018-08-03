unit ConnectionsConfigLoader;

interface

uses
  ConnectionsConfig;

type
  TConnectionsConfigLoader = class
  public
    class function Load(const ALocation: string = ''): TConnectionsConfig;
    class function LoadFromFile(const AFileName: string): TConnectionsConfig;
    class function LoadFromUrl(const AUrl: string): TConnectionsConfig;
    class function LoadFromJson(AJson: string): TConnectionsConfig;
  end;

implementation

uses
  REST.Json, System.IOUtils, Utils, System.SysUtils;

{ TConnectionsConfigLoader }

class function TConnectionsConfigLoader.Load(
  const ALocation: string): TConnectionsConfig;
begin
  if IsURL(ALocation) then
    Exit(LoadFromUrl(ALocation));

  Result:= LoadFromFile(ALocation);
end;

class function TConnectionsConfigLoader.LoadFromFile(
  const AFileName: string): TConnectionsConfig;
begin
  Result:= LoadFromJson(TFile.ReadAllText(AFileName));
end;

class function TConnectionsConfigLoader.LoadFromJson(
  AJson: string): TConnectionsConfig;
begin
  Result:= TJson.JsonToObject<TConnectionsConfig>(AJson);
end;

class function TConnectionsConfigLoader.LoadFromUrl(
  const AUrl: string): TConnectionsConfig;
begin
  Result:= LoadFromJson(HttpGetString(AUrl, 'application/json'));
end;

end.
