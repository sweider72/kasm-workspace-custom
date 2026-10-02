ARG BASE_IMAGE=kasmweb/core-ubuntu-jammy:1.18.0-rolling-weekly
FROM ${BASE_IMAGE}

USER root
ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
ENV INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

######### Customize Container Here ###########
COPY scripts/install-desktop.sh /tmp/install-desktop.sh
RUN bash /tmp/install-desktop.sh && rm /tmp/install-desktop.sh

COPY scripts/custom_startup.sh $STARTUPDIR/custom_startup.sh
RUN chmod 755 $STARTUPDIR/custom_startup.sh

ENV LANG=de_DE.UTF-8 \
    LANGUAGE=de_DE:de \
    LC_ALL=de_DE.UTF-8 \
    TZ=Europe/Berlin \
    AUTOSTART_THUNDERBIRD=true \
    AUTOSTART_NEXTCLOUD=true
######### End Customizations ###########

RUN chown 1000:0 $HOME
RUN $STARTUPDIR/set_user_permission.sh $HOME
ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME
USER 1000
