FROM flowman/confd

# Confd
ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

CMD ["--backend", "rancher", "--prefix", "/2015-07-25"]