FROM microsoft/windowsservercore

COPY bin/ /

ENTRYPOINT [ "Abmes.SQLScriptor.exe", "/logdir", "C:\\Logs\\SQLScriptor", "/config", "SQLSCRIPTOR_CONFIG_LOCATION", "/script", "SQLSCRIPTOR_SCRIPT_LOCATION", "/databases", "SQLSCRIPTOR_DATABASES" ]