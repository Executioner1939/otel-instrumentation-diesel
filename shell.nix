{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "otel-instrumentation-diesel-dev-env";
  buildInputs = with pkgs; [
    pkg-config
    postgresql
    libmysqlclient
    sqlite
  ];

  LD_LIBRARY_PATH = "${pkgs.postgresql.lib}/lib";
}
