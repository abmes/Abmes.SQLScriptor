FROM amazonlinux

COPY LinuxPAServer20.0.tar.gz /

RUN [ "yum", "groupinstall", "Development Tools", "-y" ]
RUN [ "yum", "install", "libcurl-devel.x86_64", "-y" ]
RUN [ "tar", "xvzf", "LinuxPAServer20.0.tar.gz" ]
RUN [ "rm", "LinuxPAServer20.0.tar.gz" ]
RUN [ "ln", "-s", "/usr/lib64/libncursesw.so.6.0", "/usr/lib64/libncurses.so.5" ]
RUN [ "ln", "-s", "/usr/lib64/libncursesw.so.6.0", "/usr/lib64/libtinfo.so.5" ]

ENTRYPOINT [ "PAServer-20.0/paserver" ]