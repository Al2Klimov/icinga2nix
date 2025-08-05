{ pkgs, ... }:
{
  users.groups.icinga2 = { };

  users.users.icinga2 = {
    isSystemUser = true;
    group = "icinga2";
  };

  systemd.services.icinga2 = {
    serviceConfig = {
      ExecStart = "+${pkgs.icinga2}/bin/icinga2 daemon --close-stdio -c ${./icinga2.conf}";
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
  };
}
