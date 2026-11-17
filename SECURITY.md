# Security

Report a vulnerability privately through GitHub: Security, "Report a vulnerability". Please do not open a public
issue for it.

These playbooks build a lab. They run as root inside the lab VMs and read three credentials from the working
folder by path: the pull secret, the activation key file and the generated registry password. None of them belongs
in an issue, a pull request or a log attached to one.
