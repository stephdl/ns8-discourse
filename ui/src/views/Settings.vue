<!--
  Copyright (C) 2026 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="isRouteMissing">
      <cv-column>
        <NsInlineNotification
          kind="warning"
          :title="$t('settings.no_route_title')"
          :description="$t('settings.no_route_description')"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <!-- web access -->
            <h4 class="mg-bottom-md">{{ $t("settings.web_access") }}</h4>
            <NsTextInput
              :label="$t('settings.discourse_fqdn')"
              placeholder="forum.example.org"
              v-model.trim="host"
              class="mg-bottom"
              :invalid-message="$t(error.host)"
              :disabled="stillLoading"
              ref="host"
            />
            <NsToggle
              value="letsEncrypt"
              :label="core.$t('apps_lets_encrypt.request_https_certificate')"
              v-model="isLetsEncryptEnabled"
              :disabled="stillLoading"
              class="mg-bottom"
            >
              <template #tooltip>
                <div class="mg-bottom-sm">
                  {{ core.$t("apps_lets_encrypt.lets_encrypt_tips") }}
                </div>
                <div class="mg-bottom-sm">
                  <cv-link @click="goToCertificates">
                    {{ core.$t("apps_lets_encrypt.go_to_tls_certificates") }}
                  </cv-link>
                </div>
              </template>
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </NsToggle>
            <NsInlineNotification
              v-if="isLetsEncryptCurrentlyEnabled && !isLetsEncryptEnabled"
              kind="warning"
              :title="
                core.$t('apps_lets_encrypt.lets_encrypt_disabled_warning')
              "
              :description="
                core.$t(
                  'apps_lets_encrypt.lets_encrypt_disabled_warning_description',
                  {
                    node: status.node_ui_name
                      ? status.node_ui_name
                      : status.node,
                  }
                )
              "
              :showCloseButton="false"
            />
            <NsInlineNotification
              v-if="isHostChanged"
              kind="warning"
              :title="$t('settings.host_change_title')"
              :description="$t('settings.host_change_description')"
              :showCloseButton="false"
            />
            <NsComboBox
              v-model="defaultLocale"
              :title="$t('settings.default_locale')"
              :label="$t('settings.choose_language')"
              :options="localeOptions"
              :autoFilter="true"
              :autoHighlight="true"
              :invalid-message="$t(error.default_locale)"
              :disabled="stillLoading"
              :helper-text="$t('settings.default_locale_helper')"
              class="mg-bottom maxwidth"
              ref="default_locale"
            />

            <!-- local administrator -->
            <h4 class="mg-bottom-md mg-top">
              {{ $t("settings.admin_account") }}
            </h4>
            <NsInlineNotification
              kind="info"
              :title="$t('settings.admin_account_info_title')"
              :description="
                isAdminPasswordSet
                  ? $t('settings.admin_account_info_set')
                  : $t('settings.admin_account_info_first')
              "
              :showCloseButton="false"
            />
            <NsTextInput
              :label="$t('settings.admin_username')"
              placeholder="admin"
              v-model.trim="adminUsername"
              :helper-text="$t('settings.admin_username_helper')"
              :invalid-message="$t(error.admin_username)"
              :disabled="stillLoading"
              class="mg-bottom maxwidth"
              ref="admin_username"
            />
            <NsTextInput
              :label="$t('settings.admin_email')"
              placeholder="admin@example.org"
              v-model.trim="adminEmail"
              :invalid-message="$t(error.admin_email)"
              :disabled="stillLoading"
              class="mg-bottom maxwidth"
              ref="admin_email"
            />
            <NsToggle
              v-if="isAdminPasswordSet"
              key="changeAdminPassword"
              value="changeAdminPassword"
              :label="$t('settings.change_admin_password')"
              v-model="isChangePassword"
              :disabled="stillLoading"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </NsToggle>
            <NsPasswordInput
              v-if="isPasswordActive"
              key="adminPassword"
              v-model="adminPassword"
              :newPasswordLabel="$t('settings.admin_password')"
              :confirmPasswordLabel="$t('settings.admin_password_confirm')"
              :newPasswordInvalidMessage="$t(error.admin_password)"
              :confirmPasswordInvalidMessage="$t(error.admin_password_confirm)"
              :passwordHideLabel="core.$t('password.hide_password')"
              :passwordShowLabel="core.$t('password.show_password')"
              :lengthLabel="core.$t('password.long_enough')"
              :lowercaseLabel="core.$t('password.lowercase_letter')"
              :uppercaseLabel="core.$t('password.uppercase_letter')"
              :numberLabel="core.$t('password.number')"
              :symbolLabel="core.$t('password.symbol')"
              :equalLabel="core.$t('password.equal')"
              :focus="focusPasswordField"
              :minLength="15"
              :disabled="stillLoading"
              @passwordValidation="onAdminPasswordValidation"
              class="mg-bottom maxwidth"
            />

            <!-- external OpenID Connect provider -->
            <h4 class="mg-bottom-md mg-top">
              {{ $t("settings.authentication") }}
            </h4>
            <NsToggle
              value="oidcEnabled"
              :label="$t('settings.oidc_login')"
              v-model="isOidcEnabled"
              :disabled="stillLoading"
              class="mg-bottom"
            >
              <template #tooltip>
                {{ $t("settings.oidc_login_tooltip") }}
              </template>
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </NsToggle>
            <template v-if="isOidcEnabled">
              <NsInlineNotification
                kind="info"
                :title="$t('settings.oidc_callback_title')"
                :description="
                  $t('settings.oidc_callback_description', {
                    url: oidcCallbackUrl,
                  })
                "
                :showCloseButton="false"
              />
              <NsTextInput
                :label="$t('settings.oidc_discovery_url')"
                placeholder="https://sso.example.org/realms/example/.well-known/openid-configuration"
                v-model.trim="oidcDiscoveryUrl"
                :helper-text="$t('settings.oidc_discovery_url_helper')"
                :invalid-message="$t(error.oidc_discovery_url)"
                :disabled="stillLoading"
                class="mg-bottom maxwidth"
                ref="oidc_discovery_url"
              />
              <NsTextInput
                :label="$t('settings.oidc_client_id')"
                placeholder="discourse"
                v-model.trim="oidcClientId"
                :invalid-message="$t(error.oidc_client_id)"
                :disabled="stillLoading"
                class="mg-bottom maxwidth"
                ref="oidc_client_id"
              />
              <NsToggle
                v-if="isOidcSecretSet"
                key="changeOidcSecret"
                value="changeOidcSecret"
                :label="$t('settings.change_oidc_client_secret')"
                v-model="isChangeOidcSecret"
                :disabled="stillLoading"
                class="mg-bottom"
              >
                <template slot="text-left">{{
                  $t("settings.disabled")
                }}</template>
                <template slot="text-right">{{
                  $t("settings.enabled")
                }}</template>
              </NsToggle>
              <NsTextInput
                v-if="isOidcSecretActive"
                type="password"
                :label="$t('settings.oidc_client_secret')"
                v-model="oidcClientSecret"
                :invalid-message="$t(error.oidc_client_secret)"
                :passwordHideLabel="core.$t('password.hide_password')"
                :passwordShowLabel="core.$t('password.show_password')"
                :disabled="stillLoading"
                autocomplete="new-password"
                class="mg-bottom maxwidth"
                ref="oidc_client_secret"
              />
            </template>

            <!-- notifications -->
            <h4 class="mg-bottom-md mg-top">
              {{ $t("settings.notifications") }}
            </h4>
            <NsInlineNotification
              v-if="!loading.getConfiguration && !smarthost.enabled"
              kind="warning"
              :title="$t('settings.smarthost_disabled_title')"
              :description="$t('settings.smarthost_disabled_description')"
              :actionLabel="$t('settings.go_to_smarthost')"
              @action="goToSmarthost"
              :showCloseButton="false"
            />
            <NsInlineNotification
              v-if="!loading.getConfiguration && smarthost.enabled"
              kind="info"
              :title="$t('settings.smarthost_enabled_title')"
              :description="
                $t('settings.smarthost_enabled_description', {
                  host: smarthost.host,
                })
              "
              :showCloseButton="false"
            />
            <NsTextInput
              :label="$t('settings.notification_email')"
              :placeholder="notificationEmailPlaceholder"
              v-model.trim="notificationEmail"
              :helper-text="$t('settings.notification_email_helper')"
              :invalid-message="$t(error.notification_email)"
              :disabled="stillLoading"
              class="mg-bottom maxwidth"
              ref="notification_email"
            />

            <NsInlineNotification
              v-if="error.configureModule"
              kind="error"
              :title="$t('action.configure-module')"
              :description="error.configureModule"
              :showCloseButton="false"
            />
            <NsInlineNotification
              v-if="error.getStatus"
              kind="error"
              :title="$t('action.get-status')"
              :description="error.getStatus"
              :showCloseButton="false"
            />
            <NsInlineNotification
              v-if="validationErrorDetails.length"
              kind="error"
              :title="core.$t('apps_lets_encrypt.cannot_obtain_certificate')"
              :showCloseButton="false"
            >
              <template #description>
                <div class="flex flex-col gap-2">
                  <div
                    v-for="(detail, index) in validationErrorDetails"
                    :key="index"
                  >
                    {{ detail }}
                  </div>
                </div>
              </template>
            </NsInlineNotification>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="stillLoading"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

// Discourse locale codes, from config/locales/client.*.yml of the image
const LOCALES = {
  en: "English (US)",
  en_GB: "English (UK)",
  fr: "Français",
  it: "Italiano",
  de: "Deutsch",
  es: "Español",
  pt: "Português",
  pt_BR: "Português do Brasil",
  ca: "Català",
  nl: "Nederlands",
  pl_PL: "Polski",
  sv: "Svenska",
  da: "Dansk",
  nb_NO: "Norsk bokmål",
  fi: "Suomi",
  cs: "Čeština",
  ro: "Română",
  hu: "Magyar",
  el: "Ελληνικά",
  tr_TR: "Türkçe",
  ru: "Русский",
  uk: "Українська",
  ja: "日本語",
  zh_CN: "简体中文",
  zh_TW: "繁體中文",
  ko: "한국어",
  ar: "العربية",
  he: "עברית",
};

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const USERNAME_RE = /^[A-Za-z0-9_][A-Za-z0-9_.-]{1,18}[A-Za-z0-9]$/;

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      status: {},
      validationErrorDetails: [],
      urlCheckInterval: null,
      host: "",
      configuredHost: "",
      isLetsEncryptEnabled: false,
      isLetsEncryptCurrentlyEnabled: false,
      isRouteConfigured: true,
      // empty until the configuration loads: NsComboBox shows the label only when the value changes
      defaultLocale: "",
      adminUsername: "",
      adminEmail: "",
      adminPassword: "",
      isAdminPasswordSet: false,
      isChangePassword: false,
      adminPasswordValidation: null,
      focusPasswordField: { element: "" },
      isOidcEnabled: false,
      oidcDiscoveryUrl: "",
      oidcClientId: "",
      oidcClientSecret: "",
      isOidcSecretSet: false,
      isChangeOidcSecret: false,
      smarthost: { enabled: false, host: "" },
      notificationEmail: "",
      loading: {
        getConfiguration: false,
        configureModule: false,
        getStatus: false,
      },
      error: {
        getConfiguration: "",
        configureModule: "",
        getStatus: "",
        host: "",
        lets_encrypt: "",
        default_locale: "",
        admin_username: "",
        admin_email: "",
        admin_password: "",
        admin_password_confirm: "",
        oidc_discovery_url: "",
        oidc_client_id: "",
        oidc_client_secret: "",
        notification_email: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    stillLoading() {
      return (
        this.loading.getConfiguration ||
        this.loading.configureModule ||
        this.loading.getStatus
      );
    },
    isPasswordActive() {
      // before the configuration loads every instance looks unconfigured
      if (this.loading.getConfiguration) {
        return false;
      }
      return !this.isAdminPasswordSet || this.isChangePassword;
    },
    isRouteMissing() {
      // a first configuration has no route yet: only a saved host without route means a clone
      return (
        !this.loading.getConfiguration &&
        this.configuredHost &&
        !this.isRouteConfigured
      );
    },
    isHostChanged() {
      // Discourse keeps absolute links in posts: warn before renaming a running forum
      return (
        !this.loading.getConfiguration &&
        this.configuredHost &&
        this.host &&
        this.host !== this.configuredHost
      );
    },
    isOidcSecretActive() {
      return !this.isOidcSecretSet || this.isChangeOidcSecret;
    },
    oidcCallbackUrl() {
      return `https://${this.host || "forum.example.org"}/auth/oidc/callback`;
    },
    localeOptions() {
      return Object.entries(LOCALES).map(([value, label]) => ({
        name: value,
        label,
        value,
      }));
    },
    notificationEmailPlaceholder() {
      return "noreply@" + (this.host || "forum.example.org");
    },
  },
  watch: {
    adminPassword() {
      this.error.admin_password = "";
      this.error.admin_password_confirm = "";
    },
    isChangePassword() {
      this.adminPassword = "";
      this.error.admin_password = "";
      this.error.admin_password_confirm = "";
    },
    isChangeOidcSecret() {
      this.oidcClientSecret = "";
      this.error.oidc_client_secret = "";
    },
  },
  created() {
    this.getConfiguration();
    this.getStatus();
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  methods: {
    goToCertificates() {
      this.core.$router.push("/settings/tls-certificates");
    },
    goToSmarthost() {
      this.core.$router.push("/settings/smarthost");
    },
    onAdminPasswordValidation(validation) {
      this.adminPasswordValidation = validation;
    },
    async getStatus() {
      this.loading.getStatus = true;
      this.error.getStatus = "";
      const taskAction = "get-status";
      const eventId = this.getUuid();
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getStatusAborted
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getStatusCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getStatus = this.getErrorMessage(err);
        this.loading.getStatus = false;
        return;
      }
    },
    getStatusAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getStatus = this.$t("error.generic_error");
      this.loading.getStatus = false;
    },
    getStatusCompleted(taskContext, taskResult) {
      this.status = taskResult.output;
      this.loading.getStatus = false;
    },
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.host = config.host;
      this.configuredHost = config.host;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isLetsEncryptCurrentlyEnabled = config.lets_encrypt;
      this.isRouteConfigured = config.route_configured;
      this.defaultLocale = config.default_locale;
      this.adminUsername = config.admin_username;
      this.adminEmail = config.admin_email;
      this.isAdminPasswordSet = config.admin_password_set;
      this.isOidcEnabled = config.oidc_enabled;
      this.oidcDiscoveryUrl = config.oidc_discovery_url;
      this.oidcClientId = config.oidc_client_id;
      this.isOidcSecretSet = config.oidc_client_secret_set;
      this.isChangeOidcSecret = false;
      this.oidcClientSecret = "";
      this.smarthost = config.smarthost;
      this.notificationEmail = config.notification_email;
      this.isChangePassword = false;
      this.adminPassword = "";

      this.loading.getConfiguration = false;
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);
      this.validationErrorDetails = [];
      let isValidationOk = true;

      const fail = (field, message, focus = true) => {
        this.error[field] = message;
        if (isValidationOk && focus) {
          this.focusElement(field);
        }
        isValidationOk = false;
      };

      if (!this.host) {
        fail("host", "common.required");
      } else if (!this.host.includes(".")) {
        fail("host", "settings.host_pattern");
      }
      if (!this.defaultLocale) {
        fail("default_locale", "common.required");
      }
      if (!USERNAME_RE.test(this.adminUsername)) {
        fail("admin_username", "settings.admin_username_invalid");
      }
      if (!EMAIL_RE.test(this.adminEmail)) {
        fail("admin_email", "settings.email_invalid");
      }
      if (this.isPasswordActive) {
        const v = this.adminPasswordValidation;
        const isStrong =
          v &&
          v.isLengthOk &&
          v.isLowercaseOk &&
          v.isUppercaseOk &&
          v.isNumberOk &&
          v.isSymbolOk;
        if (!isStrong) {
          fail("admin_password", "settings.admin_password_too_weak", false);
          this.focusPasswordField = { element: "newPassword" };
        } else if (!v.isEqualOk) {
          fail(
            "admin_password_confirm",
            "settings.admin_password_mismatch",
            false
          );
          this.focusPasswordField = { element: "confirmPassword" };
        }
      }
      if (this.isOidcEnabled) {
        if (!/^https?:\/\/\S+$/.test(this.oidcDiscoveryUrl)) {
          fail("oidc_discovery_url", "settings.oidc_discovery_url_invalid");
        }
        if (!this.oidcClientId) {
          fail("oidc_client_id", "common.required");
        }
        if (this.isOidcSecretActive && !this.oidcClientSecret) {
          fail("oidc_client_secret", "common.required");
        }
      }
      if (this.notificationEmail && !EMAIL_RE.test(this.notificationEmail)) {
        fail("notification_email", "settings.email_invalid");
      }
      return isValidationOk;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;
      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        if (validationError.details) {
          this.validationErrorDetails = validationError.details
            .split("\n")
            .filter((detail) => detail.trim() !== "");
        } else {
          this.error[param] = this.$t("settings." + validationError.error);
          if (!focusAlreadySet) {
            if (param === "admin_password") {
              this.focusPasswordField = { element: "newPassword" };
            } else {
              this.focusElement(param);
            }
            focusAlreadySet = true;
          }
        }
      }
    },
    async configureModule() {
      if (!this.validateConfigureModule()) {
        return;
      }

      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );

      const data = {
        host: this.host,
        lets_encrypt: this.isLetsEncryptEnabled,
        default_locale: this.defaultLocale,
        admin_username: this.adminUsername,
        admin_email: this.adminEmail,
        notification_email: this.notificationEmail,
        oidc_enabled: this.isOidcEnabled,
        oidc_discovery_url: this.isOidcEnabled ? this.oidcDiscoveryUrl : "",
        oidc_client_id: this.isOidcEnabled ? this.oidcClientId : "",
      };
      if (this.isOidcEnabled && this.isOidcSecretActive) {
        data.oidc_client_secret = this.oidcClientSecret;
      }
      if (this.isPasswordActive) {
        data.admin_password = this.adminPassword;
      }

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data,
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.mg-bottom-md {
  margin-bottom: $spacing-05;
}

.mg-top {
  margin-top: $spacing-07;
}

.maxwidth {
  max-width: 38rem;
}
</style>
