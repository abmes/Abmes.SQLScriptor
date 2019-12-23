FROM amazonlinux

COPY LinuxPAServer20.0.tar.gz /

RUN [ "yum", "groupinstall", "Development Tools", "-y" ]
RUN [ "yum", "install", "libcurl-devel.x86_64", "-y" ]
RUN [ "tar", "xvzf", "LinuxPAServer20.0.tar.gz" ]

ENTRYPOINT [ "PAServer-20.0/paserver" ]