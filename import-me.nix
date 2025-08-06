{ pkgs, ... }:
let
  icingadbSrc = pkgs.fetchFromGitHub {
    owner = "Icinga";
    repo = "icingadb";
    rev = "v1.3.0";
    hash = "sha256-2msJZqhiS8MPWlGeabiYU+wohm0L8/rUXS15QVWl32A=";
  };
in {
  users.groups.icinga2 = { };

  users.users.icinga2 = {
    isSystemUser = true;
    group = "icinga2";
  };

  systemd.services.icinga2 = with pkgs; {
    serviceConfig = {
      ExecStartPre = "+${bash}/bin/bash ${./icinga2.bash}";
      ExecStart = "+${icinga2}/bin/icinga2 daemon --close-stdio -c ${./icinga2.conf}";
      Type = "notify";
      NotifyAccess = "all";
      KillMode = "mixed";

      StateDirectory = "icinga2";
      StateDirectoryMode = "0750";
      RuntimeDirectory = "icinga2";
      RuntimeDirectoryMode = "0750";
      CacheDirectory = "icinga2";
      CacheDirectoryMode = "0750";
      User = "icinga2";
    };
    wantedBy = [ "multi-user.target" ];
    path = [ coreutils icinga2 ];
  };

  services.redis.servers.icingadb = {
    enable = true;
    port = 6380;
  };

  users.groups.icingadb = { };

  users.users.icingadb = {
    isSystemUser = true;
    group = "icingadb";
  };

  systemd.services.icingadb = {
    serviceConfig = {
      ExecStart = "${pkgs.buildGoModule {
        name = "icingadb";
        src = icingadbSrc;
        vendorHash = "sha256-hzEkfxIRQM/9ykt3qRzwZZs4NEnkHOpmzw8kY86rNps=";
        subPackages = [ "cmd/icingadb" ];
      }}/bin/icingadb -c ${./icingadb.yml}";
      Type = "notify";
      User = "icingadb";
    };
    wantedBy = [ "multi-user.target" ];
  };

  services.mysql = with pkgs; {
    enable = true;
    package = mariadb;
    initialDatabases = [
      {
        name = "icingadb";
        schema = "${icingadbSrc}/schema/mysql/schema.sql";
      }
      {
        name = "icingaweb2";
        schema = writeText "schema" ''
${builtins.readFile "${icingaweb2.src}/schema/mysql.schema.sql"}

INSERT INTO icingaweb_user VALUES ('icingaadmin', 1, '$2y$10$38ttWP3MFfQ2c5GtPEdBFuJbmgb9y5Jp9HGxeTYhYDE.5irEFpIfK', NOW(), NOW());
'';
      }
    ];
    ensureUsers = [
      {
        name = "icingadb";
        ensurePermissions."icingadb.*" = "ALL";
      }
      {
        name = "icingaweb2";
        ensurePermissions = {
          "icingaweb2.*" = "ALL";
          "icingadb.*" = "SELECT";
        };
      }
    ];
  };

  services.icingaweb2 = {
    enable = true;
    authentications.mysql = {
      backend = "db";
      resource = "icingaweb2";
    };
    roles.icingaadmin = {
      users = "icingaadmin";
      permissions = "*";
    };
    resources = let
      db = name: {
        type = "db";
        db = "mysql";
        host = "localhost";
        username = "icingaweb2";
        dbname = name;
        charset = "utf8";
      };
    in {
      icingaweb2 = db "icingaweb2";
      icingadb = db "icingadb";
    };
    modules.monitoring.enable = false;
    modulePackages.icingadb = pkgs.fetchFromGitHub {
      owner = "Icinga";
      repo = "icingadb-web";
      rev = "v1.1.3";
      hash = "sha256-vcuIOgA1TDwdB/PujP5zpyaYt1rcWuc6vKdcpIQmz+Q=";
    };
  };

  environment.etc."icingaweb2/modules/icingadb/config.ini".text = ''
[icingadb]
resource = "icingadb"
'';
}
