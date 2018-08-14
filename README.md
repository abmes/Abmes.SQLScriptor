# Abmes.SQLScriptor
SQL script executing utility

Command Line Paramaters:

  /script [ScriptFileName]                  - a .sql or .zip file (first non _*.sql inside is assumed as main script file)
  /logdir [LogsDirName]                     - directory path to store the log files for each database
  /config [FileOrHttpConfigLocation]        - location of a .json file with databse connection parameters
  /databases [CommaSeparatedFilterDBNames]  - comma separated list of databases to process. If not specified all databases will be processed
  /versionsonly                             - only display the version of each database
  
Script reserved words:

  // comment here
  /include otherscript.sql                  - * wildcard is supported
  /term=<term_symbol>                       - sets statement terminator. 
  /goto <label>
  /:<label>
  
Variables:

  %DB_VERSION%                              - version of the current database
  
