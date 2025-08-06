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

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialDatabases = [
      {
        name = "icingadb";
        schema = "${icingadbSrc}/schema/mysql/schema.sql";
      }
    ];
    ensureUsers = [
      {
        name = "icingadb";
        ensurePermissions."icingadb.*" = "ALL";
      }
    ];
  };
}
