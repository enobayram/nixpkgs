{ config, lib, pkgs, ... }:

with lib;

let
  cfg   = config.services.terraria;
  worldSizeMap = { "small" = 1; "medium" = 2; "large" = 3; };
  valFlag = name: val: optionalString (val != null) "-${name} \"${escape ["\\" "\""] (toString val)}\"";
  boolFlag = name: val: optionalString val "-${name}";
  flags = [ 
    (valFlag "port" cfg.port)
    (valFlag "maxPlayers" cfg.maxPlayers)
    (valFlag "password" cfg.password)
    (valFlag "motd" cfg.messageOfTheDay)
    (valFlag "world" cfg.worldPath)
    (valFlag "autocreate" (builtins.getAttr cfg.autoCreatedWorldSize worldSizeMap))
    (valFlag "banlist" cfg.banListPath)
    (boolFlag "secure" cfg.secure)
    (boolFlag "noupnp" cfg.noUPnP)
  ];
in
{
  options = {
    services.terraria = {
      enable = mkOption {
        type        = types.bool;
        default     = false;
        description = ''
          If enabled, starts a Terraria server. The server can be connected to via <literal>tmux -S /var/lib/terraria/terraria.sock attach</literal>
          for administration by users who are a part of the <literal>terraria</literal> group (use <literal>C-b d</literal> shortcut to detach again).
        '';
      };

      port = mkOption {
        type        = types.int;
        default     = 7777;
        description = ''
          Specifies the port to listen on.
        '';
      };

      maxPlayers = mkOption {
        type        = types.int;
        default     = 255;
        description = ''
          Sets the max number of players (between 1 and 255).
        '';
      };

      password = mkOption {
        type        = types.nullOr types.str;
        default     = null;
        description = ''
          Sets the server password. Leave <literal>null</literal> for no password.
        '';
      };

      messageOfTheDay = mkOption {
        type        = types.nullOr types.str;
        default     = null;
        description = ''
          Set the server message of the day text.
        '';
      };

      worldPath = mkOption {
        type        = types.nullOr types.path;
        default     = null;
        description = ''
          The path to the world file (<literal>.wld</literal>) which should be loaded.
          If no world exists at this path, one will be created with the size
          specified by <literal>autoCreatedWorldSize</literal>.
        '';
      };

      autoCreatedWorldSize = mkOption {
        type        = types.enum [ "small" "medium" "large" ];
        default     = "medium";
        description = ''
          Specifies the size of the auto-created world if <literal>worldPath</literal> does not
          point to an existing world.
        '';
      };

      banListPath = mkOption {
        type        = types.nullOr types.path;
        default     = null;
        description = ''
          The path to the ban list.
        '';
      };

      secure = mkOption {
        type        = types.bool;
        default     = false;
        description = "Adds additional cheat protection to the server.";
      };

      noUPnP = mkOption {
        type        = types.bool;
        default     = false;
        description = "Disables automatic Universal Plug and Play.";
      };
    };
  };

  config = mkIf cfg.enable {
    users.extraUsers.terraria = {
      description = "Terraria server service user";
      home        = "/var/lib/terraria";
      createHome  = true;
      uid         = config.ids.uids.terraria;
    };

    users.extraGroups.terraria = {
      gid = config.ids.gids.terraria;
      members = [ "terraria" ];
    };

    systemd.services.terraria = {
      description   = "Terraria Server Service";
      wantedBy      = [ "multi-user.target" ];
      after         = [ "network.target" ];

      serviceConfig = {
        User    = "terraria";
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${getBin pkgs.tmux}/bin/tmux -S /var/lib/terraria/terraria.sock new -d ${pkgs.terraria-server}/bin/TerrariaServer ${concatStringsSep " " flags}";
        ExecStop = "${getBin pkgs.tmux}/bin/tmux -S /var/lib/terraria/terraria.sock send-keys Enter \"exit\" Enter";
      };

      postStart = ''
        ${pkgs.coreutils}/bin/chmod 660 /var/lib/terraria/terraria.sock
        ${pkgs.coreutils}/bin/chgrp terraria /var/lib/terraria/terraria.sock
      '';
    };
  };
}
