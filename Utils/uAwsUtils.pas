unit uAwsUtils;

interface

uses
  System.SysUtils, System.Classes;

type
  TAwsCredentials = record
  strict private
    FAccessKeyId: string;
    FSecretAccessKey: string;
    FSessionToken: string;
    FExpiration: TDateTime;
  public
    constructor Create(
      const AAccessKeyId: string;
      const ASecretAccessKey: string;
      const ASessionToken: string;
      const AExpiration: TDateTime
    );

    property AccessKeyId: string read FAccessKeyId;
    property SecretAccessKey: string read FSecretAccessKey;
    property SessionToken: string read FSessionToken;
    property Expiration: TDateTime read FExpiration;
  end;

function GetAwsCredentials: TAwsCredentials; overload;
function GetAwsCredentials(const AJson: string): TAwsCredentials; overload;

procedure GetS3Object(const ABucketName, AObjectName, ARegion: string; const AAwsCredentials: TAwsCredentials; const AResultStream: TStream); overload;
function GetS3Object(const ABucketName, AObjectName, ARegion: string; const AAwsCredentials: TAwsCredentials): TBytes; overload;

procedure GetS3Object(const AS3Uri: string; const AAwsCredentials: TAwsCredentials; const AResultStream: TStream); overload;
function GetS3Object(const AS3Uri: string; const AAwsCredentials: TAwsCredentials): TBytes; overload;

implementation

uses
  Data.Cloud.AmazonAPI, Data.Cloud.CloudAPI, REST.HttpClient,
  System.DateUtils, System.JSON;

const
  AwsContainerTaskMetadataRoot = 'http://169.254.170.2';
  EC2CredentialsUri = 'http://169.254.169.254/latest/meta-data/identity-credentials/ec2/security-credentials/ec2-instance';

{ TAwsCredentials }

constructor TAwsCredentials.Create(const AAccessKeyId, ASecretAccessKey,
  ASessionToken: string; const AExpiration: TDateTime);
begin
  FAccessKeyId:= AAccessKeyId;
  FSecretAccessKey:= ASecretAccessKey;
  FSessionToken:= ASessionToken;
  FExpiration:= AExpiration;
end;

function GetAwsCredentials: TAwsCredentials; overload;
begin
  var AwsAccessKeyId:= GetEnvironmentVariable('AWS_ACCESS_KEY_ID');
  var AwsSecretAccessKey:= GetEnvironmentVariable('AWS_SECRET_ACCESS_KEY');
  var AwsSessionToken:= GetEnvironmentVariable('AWS_SESSION_TOKEN');

  try
    if (AwsAccessKeyId <> '') and (AwsSecretAccessKey <> '') and (AwsSessionToken <> '') then
      Result:= TAwsCredentials.Create(AwsAccessKeyId, AwsSecretAccessKey, AwsSessionToken, Now + 10 * 365)
    else
      begin
        var AwsContainerCredentialsRelativeUri:= GetEnvironmentVariable('AWS_CONTAINER_CREDENTIALS_RELATIVE_URI');

        if (AwsContainerCredentialsRelativeUri <> '') then
          Result:= GetAwsCredentials(AwsContainerTaskMetadataRoot + AwsContainerCredentialsRelativeUri)
        else
          try
            Result:= GetAwsCredentials(EC2CredentialsUri);
          except
            raise Exception.Create('Environment variables AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN or AWS_CONTAINER_CREDENTIALS_RELATIVE_URI not specified and EC2 credentials not available');
          end;
      end;
  except
    on E: Exception do
      raise Exception.Create('Could not obtain AWS credentials: ' + E.Message);
  end;
end;

function GetAwsCredentials(const AJson: string): TAwsCredentials;
begin
  var j:= TJSONObject.ParseJSONValue(AJson) as TJSONObject;;

  Result:=
    TAwsCredentials.Create(
      j.Values['AccessKeyId'].Value,
      j.Values['SecretAccessKey'].Value,
      j.Values['Token'].Value,
      ISO8601ToDate(j.Values['Expiration'].Value, False)
    );
end;

type
  TSessionAmazonConnectionInfo = class(TAmazonConnectionInfo)
  strict private
    FSessionToken: string;
  published
    property SessionToken: string read FSessionToken write FSessionToken;
  end;

type
  TSessionAmazonStorageService = class(TAmazonStorageService)
  protected
    function PrepareRequest(const HTTPVerb: string; Headers, QueryParameters: TStringList;
                            const QueryPrefix: string; var URL: string; var Content: TStream): TCloudHTTP; override;
  end;

{ TSessionAmazonStorageService }

function TSessionAmazonStorageService.PrepareRequest(const HTTPVerb: string;
  Headers, QueryParameters: TStringList; const QueryPrefix: string;
  var URL: string; var Content: TStream): TCloudHTTP;
begin
  if (ConnectionInfo is TSessionAmazonConnectionInfo) and
     ((ConnectionInfo as TSessionAmazonConnectionInfo).SessionToken <> '') then
    Headers.Values['x-amz-security-token']:=
      (ConnectionInfo as TSessionAmazonConnectionInfo).SessionToken;

  Result:=
    inherited PrepareRequest(HTTPVerb, Headers, QueryParameters, QueryPrefix, URL, Content);
end;

{ unit routines}

procedure GetS3Object(const ABucketName, AObjectName, ARegion: string; const AAwsCredentials: TAwsCredentials; const AResultStream: TStream); overload;
begin
  var ConnectionInfo:= TSessionAmazonConnectionInfo.Create(nil);
  try
    ConnectionInfo.AccountName:= AAwsCredentials.AccessKeyId;
    ConnectionInfo.AccountKey:= AAwsCredentials.SecretAccessKey;
    ConnectionInfo.SessionToken:= AAwsCredentials.SessionToken;

    var Service:= TSessionAmazonStorageService.Create(ConnectionInfo);
    try
      var Response:= TCloudResponseInfo.Create;
      try
        Service.GetObject(ABucketName, AObjectName, AResultStream, Response, ARegion);

        if (Response.StatusCode >= 400) then
          raise EHTTPProtocolException.Create(Response.StatusCode, Response.StatusMessage, Response.StatusMessage);
      finally
        Response.Free;
      end;
    finally
      Service.Free;
    end;
  finally
    ConnectionInfo.Free;
  end;
end;

function GetS3Object(const ABucketName, AObjectName, ARegion: string; const AAwsCredentials: TAwsCredentials): TBytes;
begin
  var Stream:= TMemoryStream.Create();
  try
    GetS3Object(ABucketName, AObjectName, ARegion, AAwsCredentials, Stream);

    SetLength(Result, Stream.Size);
    Stream.Position:= 0;
    Stream.ReadData(Result, Stream.Size);
  finally
    Stream.Free;
  end;
end;

procedure ParseS3Uri(const AS3Uri: string; out ABucketName, AObjectName, ARegion: string);
begin
  var path:= AS3Uri.Substring(Length('s3://'));
  var p:= Pos('/', path);

  var Endpoint:= path.Substring(0, p-1);

  if Endpoint.StartsWith('s3.', True) then
    begin
      var path2:= path.Substring(p);
      var p2:= Pos('/', path2);

      ABucketName:= path2.Substring(0, p2-1);
      AObjectName:= path2.Substring(p2);

      ARegion:= Endpoint.Split(['.'])[1];
    end
  else
    begin
      ABucketName:= Endpoint.Split(['.'])[0];
      AObjectName:= path.Substring(p);
      ARegion:= Endpoint.Split(['.'])[2];
    end;
end;

procedure GetS3Object(const AS3Uri: string; const AAwsCredentials: TAwsCredentials; const AResultStream: TStream);
var
  BucketName: string;
  ObjectName: string;
  Region: string;
begin
  ParseS3Uri(AS3Uri, BucketName, ObjectName, Region);
  GetS3Object(BucketName, ObjectName, Region, AAwsCredentials, AResultStream);
end;

function GetS3Object(const AS3Uri: string; const AAwsCredentials: TAwsCredentials): TBytes;
var
  BucketName: string;
  ObjectName: string;
  Region: string;
begin
  ParseS3Uri(AS3Uri, BucketName, ObjectName, Region);
  Result:= GetS3Object(BucketName, ObjectName, Region, AAwsCredentials);
end;

end.
