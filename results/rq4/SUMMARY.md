# RQ4: decision fidelity - capability gate vs inventory gate

Per project: does each approach pass the sane build and reject the leaky one?

project              | capa sane | capa leaky | inv sane | inv leaky | capaDisc | invDisc
---------------------+-----------+------------+----------+-----------+----------+--------
capa_paymentguard    | PASS      | FAIL       | 6        | 6         | yes      | no
capa_dataguard       | PASS      | FAIL       | 6        | 6         | yes      | no
capa_supplygate      | PASS      | FAIL       | 3        | 3         | yes      | no
capa_configbroker    | PASS      | FAIL       | 3        | 3         | yes      | no
capa_licenseaudit    | PASS      | FAIL       | 3        | 3         | yes      | no

Fidelity: capability 5/5, inventory 0/5

The inventory (syft) is byte-identical for the sane and leaky directories
because the scanner reads the dependency manifest, not the .capa source, so
it gives the same decision for both members of every pair. The capability
approach certifies the sane pipeline and the analyzer rejects the leaky
module, so the certificate differs on every pair.
