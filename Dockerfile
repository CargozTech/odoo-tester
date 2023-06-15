FROM ubuntu:22.04

# Odoo version
#
ENV ODOO_VERSION 15.0
ENV PG_VERSION 12
ENV LANG C.UTF-8
ENV TZ=Asia/Dubai \
    DEBIAN_FRONTEND=noninteractive

# Odoo requires a non-standard build of wkhtmltopdf for many use cases
# (including running without a local X display).
#
ENV H2P_BASE https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download
ENV H2P_VER 0.12.5
ENV H2P_REL 1
ENV H2P_FILE wkhtmltox-${H2P_VER}-${H2P_REL}.centos7.x86_64.rpm
ENV H2P_URI ${H2P_BASE}/${H2P_VER}/${H2P_FILE}

# Packages
#
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        gnupg \
        libfreetype6-dev \
        libfribidi-dev \
        libharfbuzz-dev \
        libjpeg8-dev \
        liblcms2-dev \
        libopenjp2-7-dev \
        libpq-dev \
        libtiff5-dev \
        libwebp-dev \
        libxcb1-dev \
        libxslt1-dev \
        python3-dev \
        python3-pip \
        unzip \
        zlib1g-dev \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
        python3-coverage \
        libxml2-dev


# install latest postgresql and postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-${PG_VERSION} postgresql-client-${PG_VERSION} \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*


# PostgreSQL tuning
#
USER postgres
ENV PGDATA /etc/postgresql/${PG_VERSION}/main
COPY postgresql.conf.nosync ${PGDATA}/postgresql.conf.nosync
RUN cat ${PGDATA}/postgresql.conf.nosync >> ${PGDATA}/postgresql.conf

# Odoo user and database
#
USER root
RUN useradd odoo
USER postgres
RUN service postgresql start ; \
    createuser odoo ; \
    createdb --owner odoo odoo ; \
    service postgresql stop

# Odoo wrapper script
#
USER root
RUN mkdir /opt/odoo-addons
RUN mkdir /var/lib/odoo ; chown odoo /var/lib/odoo
COPY odoo-wrapper /usr/local/bin/odoo-wrapper
COPY requirements.txt /opt/odoo-${ODOO_VERSION}-requirements.txt

# Upstream Odoo snapshot
#
ADD https://codeload.github.com/odoo/odoo/zip/${ODOO_VERSION} /opt/odoo.zip
USER root
RUN unzip -q -d /opt /opt/odoo.zip ; \
    ln -s /opt/odoo-${ODOO_VERSION} /opt/odoo

RUN pip install setuptools wheel
RUN pip install -r /opt/odoo-${ODOO_VERSION}-requirements.txt

# Create base Odoo database
#
USER root
RUN odoo-wrapper --without-demo=all

# Entry point
#
ENTRYPOINT ["/usr/local/bin/odoo-wrapper"]
