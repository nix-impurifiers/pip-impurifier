# SPDX-License-Identifier: MIT
{ pkgs, backend }:
let
  wheel =
    version:
    backend.makeWheel {
      name = "impurifier-proof";
      inherit version;
      pure = false;
      tag = "py3-none-linux_x86_64";
      payload = pkgs.runCommand "wheel-native-${version}" { nativeBuildInputs = [ pkgs.stdenv.cc ]; } ''
        mkdir -p $out/impurifier_proof
        echo 'int value(void) { return ${version}; }' > proof.c
        $CC -shared -fPIC -nostdlib proof.c -o $out/impurifier_proof/proof.so
        cat > $out/impurifier_proof/__init__.py <<'PY'
        from ctypes import CDLL
        from pathlib import Path
        def value(): return CDLL(str(Path(__file__).parent / 'proof.so')).value()
        PY
      '';
    };
in
{
  native-vm = pkgs.testers.runNixOSTest {
    name = "pip-native-wheel-lifecycle";
    globalTimeout = 600;
    requiredFeatures = {
      kvm = false;
      devnet = false;
    };
    nodes.machine = { lib, ... }: {
      virtualisation.qemu.package = lib.mkForce pkgs.qemu;
      virtualisation.qemu.forceAccel = false;
      environment.systemPackages = [ backend.package ];
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("python3 -m venv --without-pip /srv/venv")
      pip = "python3 -m pip --python /srv/venv install --no-index --no-deps "
      machine.succeed(pip + "${wheel "1"}/*.whl")
      assert machine.succeed("/srv/venv/bin/python -c 'import impurifier_proof; print(impurifier_proof.value())'").strip() == "1"
      machine.succeed("python3 -m pip --python /srv/venv check")
      machine.succeed(pip + "--upgrade ${wheel "2"}/*.whl")
      assert machine.succeed("/srv/venv/bin/python -c 'import impurifier_proof; print(impurifier_proof.value())'").strip() == "2"
      machine.succeed("python3 -m pip --python /srv/venv uninstall -y impurifier-proof")
      machine.fail("/srv/venv/bin/python -c 'import impurifier_proof'")
      machine.succeed("test ! -e /srv/venv/nix; test -z \"$(find /srv/venv -name proof.so)\"")
    '';
  };
}
