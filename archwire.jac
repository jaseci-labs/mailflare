graph layers {
    layer all { *; }
}

graph spaces {
    space mailflare: node { "."; }
}

graph import {
    src.lib.jac.host ++> "src/lib/email/inbound-notification" { at, record }
    src.lib.jac.host ++> "src/lib/email/trash-retention-utils" { NULL }
    src.lib.jac.host ++> "src/lib/email/shared-file-notice" { record, rx, rx_sub }
    src.lib.jac.host ++> "src/lib/email/recipient-address" { NULL, record }
    src.lib.jac.host ++> "src/lib/email/sender-label" { either, rx, rx_sub }
    "src/lib/email/unsubscribe-types.d" --> src.lib.email.unsubscribe { UnsubscribeUrl }
    src.lib.jac.host ++> "src/lib/email/resend-api" { NULL, at, either, merged, nil, record, rx, rx_sub }
    src.lib.jac.host ++> "src/lib/email/attachment-risk" { NULL, at, nil, record, rx, rx_sub }
    src.lib.jac.host ++> "src/lib/email/bulk-mail" { NULL, entries, record }
    src.lib.jac.host ++> "src/lib/email/mime-preflight" { NULL, record }
    src.lib.jac.host ++> "src/lib/email/intake-signature" { record }
    src.lib.jac.host ++> "src/lib/email/attachment-limits" { NULL }
    src.lib.jac.host ++> "src/lib/email/inbound-limits" { NULL, merged, record, rx, rx_sub }
    src.lib.jac.host ++> src.lib.email.svix { NULL, at, record }
    src.lib.jac.host ++> "src/lib/email/inbound-id" { either }
    src.lib.jac.host ++> "src/lib/email/stale-objects" { at, record }
    src.lib.jac.host ++> "src/lib/email/thread-lookup" { NULL, either, rx, rx_sub }
    src.lib.jac.host ++> "src/lib/email/mail-type-rule" { nil }
    src.lib.jac.host ++> src.lib.email.base64 { rx, rx_sub }
    src.lib.security.headers --> "next.config" { getSecurityHeaders }
    server.runtime.mailer --> "server/runtime/types.d" { Mailer }
    server.runtime.queue --> "server/runtime/types.d" { InProcessQueue }
    server.runtime.realtime --> "server/runtime/types.d" { RealtimeHubRegistry }
    "server/runtime/sqlite-database" --> "server/runtime/types.d" { SqliteDatabase }
    src.lib.email.address --> server.runtime.mailer { getEmailAddress }
    src.lib.utils ++> src.lib.email.address { parseAddress }
    src.lib.jac.host ++> src.lib.email.address { NULL, record, rx, rx_sub }
    src.lib.realtime.revision --> server.runtime.realtime { getUserMailRevision }
    "src/lib/realtime/types.d" --> server.runtime.realtime { RevisionNotification, RevisionPing }
    "src/lib/realtime/types.d" --> src.lib.realtime.revision { MailboxRevisionRow }
    src.lib.i18n.utils --> "src/app/(admin)/accounts/[id]/password/types.d" { Translator }
    "src/app/(admin)/accounts/[id]/types.d" --> "src/app/(admin)/accounts/[id]/password/types.d" {
        ManagedAccount,
    }
    src.lib.i18n.locales --> src.lib.i18n.utils { DEFAULT_LOCALE, locales }
    "src/lib/i18n/types.d" --> src.lib.i18n.utils { Locale, Messages, PluralKey, TranslationKey }
    src.lib.i18n.locales --> "src/lib/i18n/types.d" { Locale }
    "src/app/(admin)/accounts/types.d" --> "src/app/(admin)/accounts/accounts-table-types.d" {
        Account,
    }
    "src/lib/agent/provider-types.d" --> "src/app/(admin)/agent/types.d" {
        AgentModelOption,
        AgentModelRates,
        AgentProviderKind,
        AgentProviderPreset,
        AgentProviderPublicConfig,
    }
    "src/lib/backups/types.d" --> "src/app/(admin)/backups/types.d" { BackupTableGroupId }
    "src/lib/i18n/types.d" --> "src/app/(admin)/licenses/types.d" { TranslationKey }
    src.components.icons --> "src/app/(admin)/licenses/types.d" { LucideIcon }
    "src/lib/licenses/types.d" --> "src/app/(admin)/licenses/types.d" { LicenseStatus }
    src.lib.utils --> src.components.icons { cn }
    "src/lib/spam/types.d" --> "src/app/(admin)/spam-filter/types.d" {
        SpamBrand,
        SpamIntelligenceStatus,
    }
    src.lib.email.parse --> "src/lib/spam/types.d" { ParsedEmail }
    src.lib.email.address --> src.lib.email.parse { formatPostalAddress, formatPostalAddressList }
    src.lib.email.threading --> src.lib.email.parse { parseMessageIdList }
    "src/lib/email/mime-preflight" --> src.lib.email.parse { MIME_LIMITS, mimePreflightReason }
    src.lib.email.attachments --> src.lib.email.parse { normalizeAttachmentContent }
    "src/lib/email/reply-content-utils" --> src.lib.email.parse {
        getLatestEmailContent,
        htmlToReadableText,
    }
    "src/lib/email/attachment-types.d" --> src.lib.email.parse { AttachmentContent }
    src.db.index --> src.lib.email.threading { getDb }
    src.db.schema.index --> src.lib.email.threading { messages }
    src.db.sql --> src.lib.email.threading { escapeLike, insensitiveLike }
    src.lib.email.address --> src.lib.email.threading { addressListIncludes }
    src.lib.ids --> src.lib.email.threading { newId }
    "src/lib/email/threading-types.d" --> src.lib.email.threading { ResolveThreadInput }
    "src/lib/email/thread-lookup" --> src.lib.email.threading {
        normalizeMessageId,
        selectThreadLookupIds,
    }
    src.db.schema.index --> src.db.index { schema }
    src.db.external --> src.db.index { isExternalDatabase }
    src.db.schema.kits --> src.db.schema.index { kit }
    src.db.dialect --> src.db.schema.kits { DatabaseDialect, schemaDialect }
    src.db.compat --> src.db.external { ExecutorContext, currentExecutor, wrapDatabase }
    "src/db/d1-compat" --> src.db.external { CompatDatabase }
    src.db.dialect --> src.db.external { DatabaseConfig }
    src.db.drivers.mysql --> src.db.external { openMysql2, openPlanetScale }
    src.db.drivers.postgres --> src.db.external {
        openNeon,
        openNodePostgres,
        openPglite,
        openPostgresJs,
    }
    src.db.drivers.sqlite --> src.db.external { openBetterSqlite3, openBunSqlite, openLibsql }
    src.db.drivers.types --> src.db.external { OpenOptions, SqlExecutor }
    src.db.dialect --> src.db.compat { DatabaseDialect }
    src.db.drivers.types --> src.db.compat { RowMode, SqlExecutor }
    src.db.dialect --> src.db.drivers.types { DatabaseDialect }
    src.db.dialect --> "src/db/d1-compat" { DatabaseDialect }
    src.db.drivers.types --> "src/db/d1-compat" { SqlExecutor, normalizeParam, numberPlaceholders }
    src.db.drivers.types --> src.db.drivers.mysql {
        OpenOptions,
        SqlExecutor,
        lazyExecutor,
        normalizeParam,
    }
    src.db.drivers.types --> src.db.drivers.postgres {
        OpenOptions,
        QueryResult,
        RowMode,
        SqlExecutor,
        lazyExecutor,
        normalizeParam,
    }
    src.db.drivers.types --> src.db.drivers.sqlite {
        OpenOptions,
        QueryResult,
        SqlExecutor,
        lazyExecutor,
        normalizeParam,
    }
    src.db.dialect --> src.db.sql { schemaDialect }
    src.db.index --> src.lib.email.attachments { getDb }
    src.db.schema.index --> src.lib.email.attachments { messageAttachments, messages }
    src.lib.ids --> src.lib.email.attachments { newId }
    "src/lib/email/attachment-risk" --> src.lib.email.attachments {
        AttachmentRisk,
        assessAttachmentRisk,
        inspectZipDirectory,
        locateZipDirectory,
        mergeRisks,
    }
    "src/lib/email/inbound-limits" --> src.lib.email.attachments { truncateUtf8 }
    "src/lib/email/draft-access" --> src.lib.email.attachments { isOthersDraft }
    src.lib.mailboxes.access --> src.lib.email.attachments { getMailboxAccessLevel }
    "src/lib/auth/types.d" --> src.lib.email.attachments { SessionUser }
    "src/lib/email/attachment-types.d" --> src.lib.email.attachments {
        AttachmentContent,
        AttachmentMetadata,
        StoredAttachment,
    }
    "src/lib/email/attachment-limits" --> src.lib.email.attachments {
        DEFAULT_OUTBOUND_ATTACHMENT_MAX_MB,
        outgoingSizeError,
    }
    "src/lib/email/attachment-policy" --> src.lib.email.attachments { getOutboundAttachmentMaxMb }
    "src/lib/drive/shared-objects" --> src.lib.email.attachments { deleteUnreferencedObjects }
    src.db.index --> "src/lib/email/draft-access" { AppDatabase }
    src.db.schema.index --> "src/lib/email/draft-access" { jmapChanges, messages }
    src.db.index --> src.lib.mailboxes.access { AppDatabase }
    src.db.schema.index --> src.lib.mailboxes.access { domains, mailboxAccess, mailboxes, users }
    "src/lib/accounts/deletion-utils" --> src.lib.mailboxes.access { getAccountStatus }
    "src/lib/auth/types.d" --> src.lib.mailboxes.access { SessionUser }
    "src/lib/mailboxes/access-utils" --> src.lib.mailboxes.access { isTeamMailboxSharingEnabled }
    "src/lib/mailboxes/types.d" --> src.lib.mailboxes.access {
        MailboxAccessLevel,
        MailboxPermission,
    }
    src.db.index --> "src/lib/mailboxes/access-utils" { AppDatabase }
    src.db.schema.index --> "src/lib/mailboxes/access-utils" { licenseSettings }
    src.db.schema.index --> "src/lib/mailboxes/types.d" { mailboxes }
    "src/lib/aws/aws-types.d" --> "src/lib/email/outbound-provider-types.d" { AwsConfig }
    src.db.index --> "src/lib/email/attachment-policy" { getDb }
    src.db.schema.index --> "src/lib/email/attachment-policy" { appSettings }
    src.lib.runtime --> "src/lib/email/attachment-policy" { isNodeRuntime }
    "src/lib/email/attachment-limits" --> "src/lib/email/attachment-policy" {
        CLOUD_ATTACHMENT_THRESHOLD_BYTES,
        DEFAULT_OUTBOUND_ATTACHMENT_MAX_MB,
        clampOutboundAttachmentMb,
        outboundAttachmentCeilingMb,
    }
    src.db.index --> "src/lib/drive/shared-objects" { AppDatabase }
    src.db.schema.index --> "src/lib/drive/shared-objects" { driveItems, messageAttachments }
    "src/lib/email/reply-content-types.d" --> "src/lib/email/reply-content-utils" {
        PreviousMessageDirection,
        QuotedEmailContent,
        ReplyContentParts,
        SplitReplyContentOptions,
    }
    src.lib.email.address --> "src/lib/email/reply-content-utils" { normalizeEmailAddress }
    "src/app/(calendar)/booking/types.d" --> "src/app/(calendar)/booking/editor-types.d" {
        BookingForm,
        BookingHost,
    }
    "src/lib/booking/types.d" --> "src/app/(calendar)/booking/types.d" { BookingTimeRange }
    "src/app/(calendar)/calendar/types.d" --> "src/app/(calendar)/calendar/day-events-types.d" {
        CalendarEvent,
        EventResizeEdge,
    }
    "src/lib/calendar/types.d" --> "src/app/(calendar)/calendar/types.d" { CalendarRepeat }
    "src/app/(calendar)/calendar/types.d" --> "src/app/(calendar)/upcoming-sidebar-types.d" {
        CalendarEvent,
    }
    "src/hooks/types.d" --> "src/app/(dashboard)/inbox/[messageId]/types.d" { Message }
    "src/lib/email/reply-content-types.d" --> "src/app/(dashboard)/inbox/[messageId]/types.d" {
        ReplyContentParts,
    }
    "src/lib/migrations/types.d" --> "src/app/api/admin/migrations/types.d" {
        MigrationResult,
        MigrationStatus,
    }
    "src/lib/backups/types.d" --> "src/app/api/backups/types.d" {
        BackupScheduleType,
        BackupTableGroupId,
    }
    "src/lib/calendar/types.d" --> "src/app/api/calendar/events/types.d" { CalendarRepeat }
    "src/app/api/drafts/types.d" --> "src/app/api/drafts/[id]/types.d" { DraftPayload }
    "src/lib/licenses/types.d" --> "src/app/api/licenses/types.d" { LicensePlan, LicenseStatus }
    src.db.index --> "src/app/api/messages/[messageId]/attachments.zip/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/attachments.zip/route" {
        messageAttachments,
        messages,
    }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/attachments.zip/route" {
        getCurrentUser,
    }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/attachments.zip/route" { getEnv }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/attachments.zip/route" {
        getMailboxAccessLevel,
    }
    "src/lib/email/draft-access" --> "src/app/api/messages/[messageId]/attachments.zip/route" {
        isOthersDraft,
    }
    src.lib.zip --> "src/app/api/messages/[messageId]/attachments.zip/route" { createZipStream }
    src.lib.email.attachments --> "src/app/api/messages/[messageId]/attachments.zip/route" {
        assessStoredAttachment,
    }
    "src/app/api/messages/[messageId]/attachments/[attachmentId]/utils" --> "src/app/api/messages/[messageId]/attachments.zip/route" {
        getAttachmentContentDisposition,
    }
    "src/app/api/messages/[messageId]/attachments.zip/utils" --> "src/app/api/messages/[messageId]/attachments.zip/route" {
        attachmentsZipName,
    }
    "src/app/api/messages/[messageId]/attachments.zip/types.d" --> "src/app/api/messages/[messageId]/attachments.zip/route" {
        AttachmentsZipRouteParams,
    }
    src.lib.auth.session --> src.lib.auth.cookies { SESSION_COOKIE, getUserFromSession }
    src.lib.auth.origin --> src.lib.auth.cookies { hasValidSessionMutationOrigin }
    src.lib.auth.unauthorized --> src.lib.auth.cookies { UnauthorizedError }
    "src/lib/auth/app-passwords" --> src.lib.auth.session { revokeAllAppPasswords }
    "src/lib/auth/device-keys" --> src.lib.auth.session { revokeAllDeviceKeys }
    src.lib.ids --> src.lib.auth.session { newId }
    src.db.index --> src.lib.auth.session { getDb }
    src.db.schema.index --> src.lib.auth.session { sessions, users }
    src.db.index --> "src/lib/auth/app-passwords" { getDb }
    src.db.schema.index --> "src/lib/auth/app-passwords" { apiKeys }
    "src/lib/api/find-api-key" --> "src/lib/auth/app-passwords" { isApiKeyVerificationCached }
    "src/lib/api/key-auth" --> "src/lib/auth/app-passwords" { authenticateApiKeyValue }
    "src/lib/api/key-auth-types.d" --> "src/lib/auth/app-passwords" { ApiAuthResult }
    src.lib.api.scopes --> "src/lib/auth/app-passwords" { AppPasswordScope }
    "src/lib/api-keys" --> "src/lib/auth/app-passwords" { apiKeyLookupPrefix }
    "src/lib/auth/app-password-utils" --> "src/lib/auth/app-passwords" { isListedAsAppPassword }
    "src/lib/auth/client-ip" --> "src/lib/auth/app-passwords" { getClientIp }
    src.lib.dav.settings --> "src/lib/auth/app-passwords" { isDavEnabled }
    src.lib.runtime --> "src/lib/auth/app-passwords" { isNodeRuntime }
    src.db.index --> "src/lib/api/find-api-key" { AppDatabase }
    src.db.schema.index --> "src/lib/api/find-api-key" { apiKeys }
    "src/lib/api-keys" --> "src/lib/api/find-api-key" {
        apiKeyLookupPrefix,
        hashApiKey,
        timingSafeEqualText,
        verifyApiKey,
    }
    src.lib.ids --> "src/lib/api-keys" { newId }
    src.db.index --> "src/lib/api/key-auth" { getDb }
    src.db.schema.index --> "src/lib/api/key-auth" { apiKeys, mcpKeyMailboxes, users }
    "src/lib/api-keys" --> "src/lib/api/key-auth" { parseScopes }
    "src/lib/api/find-api-key" --> "src/lib/api/key-auth" { findApiKeyForSecret }
    "src/lib/api/key-auth-types.d" --> "src/lib/api/key-auth" { ApiAuthResult }
    src.lib.api.scopes --> "src/lib/api/key-auth" { ADMIN_API_KEY_SCOPES }
    "src/lib/auth/client-ip" --> "src/lib/api/key-auth" { getClientIp }
    src.db.schema.index --> "src/lib/api/key-auth-types.d" { users }
    "src/lib/api-keys" --> "src/lib/auth/app-password-utils" { parseScopes }
    src.db.index --> src.lib.dav.settings { getDb }
    src.db.schema.index --> src.lib.dav.settings { appSettings }
    "src/lib/database-errors" --> src.lib.dav.settings { isMissingColumnError }
    src.db.index --> "src/lib/auth/device-keys" { getDb }
    src.db.schema.index --> "src/lib/auth/device-keys" { apiKeys, pushDevices }
    "src/lib/api-keys" --> "src/lib/auth/device-keys" { generateApiKey, scopesToJson }
    src.lib.ids --> "src/lib/auth/device-keys" { newId }
    src.lib.runtime --> src.lib.auth.origin { getNodeEnv }
    src.lib.runtime --> src.lib.cloudflare { getNodeEnv }
    "src/lib/d1-session-context" --> src.lib.cloudflare { getD1Session, withD1Session }
    "src/db/with-database" --> src.lib.cloudflare { withDatabase }
    src.lib.storage.index --> src.lib.cloudflare { withStorage }
    src.db.dialect --> "src/db/with-database" { DatabaseConfig, resolveDatabaseConfig }
    src.db.external --> "src/db/with-database" { ExternalDatabase, openExternalDatabase }
    "src/lib/storage/b2-config" --> src.lib.storage.index { getObjectStorageConfig }
    "src/lib/storage/b2-bucket" --> src.lib.storage.index { openB2Bucket }
    "src/lib/storage/b2-types.d" --> "src/lib/storage/b2-config" { B2Config, StorageStatus }
    src.lib.aws.client --> "src/lib/storage/b2-bucket" { AwsError, awsRequest }
    src.lib.aws.xml --> "src/lib/storage/b2-bucket" { xmlBlocks, xmlTag }
    "src/lib/aws/aws-types.d" --> "src/lib/storage/b2-bucket" { AwsConfig }
    "src/lib/storage/b2-types.d" --> "src/lib/storage/b2-bucket" { B2Config, B2HttpMetadata }
    src.lib.aws.sigv4 --> src.lib.aws.client { signAwsRequest }
    src.lib.aws.xml --> src.lib.aws.client { xmlTag }
    "src/lib/aws/aws-types.d" --> src.lib.aws.client { AwsConfig }
    "src/lib/aws/aws-types.d" --> src.lib.aws.sigv4 { AwsCredentials }
    "src/lib/email/inbound-limits" --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/utils" {
        truncateUtf8,
    }
    "src/lib/email/inbound-limits" --> "src/app/api/messages/[messageId]/attachments.zip/utils" {
        truncateUtf8,
    }
    "src/lib/email/unsubscribe-types.d" --> "src/app/api/messages/[messageId]/unsubscribe/types.d" {
        MailtoUnsubscribeTarget,
        UnsubscribeMethod,
    }
    "src/hooks/types.d" --> "src/app/api/messages/counts/types.d" { MessageCounts, MessageFolder }
    src.db.schema.index --> "src/app/api/messages/counts/types.d" { messages }
    "src/app/api/messages/bulk/types.d" --> "src/app/api/messages/empty/types.d" {
        PermanentDeleteFolder,
    }
    src.db.index --> "src/app/api/messages/types.d" { AppDatabase }
    src.db.schema.index --> "src/app/api/messages/types.d" { messages }
    "src/lib/email/attachment-types.d" --> "src/app/api/send/types.d" { AttachmentContent }
    src.lib.validators --> "src/app/api/settings/forwarding/types.d" { updateForwardingEmailSchema }
    src.lib.api.scopes --> src.lib.validators { APP_PASSWORD_PROTOCOLS }
    "src/lib/security/public-url" --> src.lib.validators {
        PUBLIC_HTTPS_URL_MESSAGE,
        isPublicHttpsUrl,
    }
    src.lib.domains.utils --> src.lib.validators { isValidHostname, normalizeHostname }
    src.lib.email.address --> src.lib.validators { getEmailAddress, splitEmailAddressList }
    "src/lib/email/recipient-address" --> src.lib.validators { normalizeRecipientLocalPart }
    src.lib.folders.colors --> src.lib.validators { DEFAULT_FOLDER_COLOR, FOLDER_COLOR_VALUES }
    "src/lib/follow-ups/follow-up-utils" --> src.lib.validators { MAX_FOLLOW_UP_DAYS }
    src.lib.email.base64 --> src.lib.validators { isValidBase64 }
    "src/lib/email/mail-type-rule" --> src.lib.validators {
        MAIL_TYPE_BULK,
        MAIL_TYPE_UNSAFE_ACTION,
    }
    "src/lib/dns-query" --> "src/lib/security/public-url" { queryDns }
    "src/lib/remote-images/fetch" --> "src/lib/security/public-url" {
        isForbiddenHostname,
        isIpLiteral,
        isPublicAddress,
    }
    "src/lib/dns-query" --> "src/lib/remote-images/fetch" { queryDns }
    "src/lib/spam/domain-utils" --> "src/lib/remote-images/fetch" { isPublicIpv4 }
    src.lib.spam.analyzers.utils --> "src/lib/spam/domain-utils" { findHeader }
    src.lib.utils ++> "src/lib/email/recipient-address" { parseAddress }
    "src/lib/folders/types.d" --> src.lib.folders.colors { FolderColorOption }
    src.lib.validators --> "src/app/api/settings/password/types.d" { changePasswordSchema }
    src.lib.validators --> "src/app/api/settings/profile/types.d" { updateProfileSchema }
    src.lib.validators --> "src/app/api/settings/recipient-addresses/types.d" {
        updateRecipientAddressSettingsSchema,
    }
    src.lib.validators --> "src/app/api/settings/shortcuts/types.d" {
        updateShortcutsSettingsSchema,
    }
    src.lib.validators --> "src/app/api/settings/spam/types.d" { updateSpamSettingsSchema }
    src.lib.validators --> "src/app/api/settings/trash-retention/types.d" {
        updateTrashRetentionSettingsSchema,
    }
    src.lib.cloudflare --> "src/app/jmap/[[...segments]]/route" { getEnv }
    src.lib.jmap.handler --> "src/app/jmap/[[...segments]]/route" { handleJmapRequest }
    src.db.index --> src.lib.jmap.handler { getDb }
    "src/lib/api/key-auth" --> src.lib.jmap.handler { authenticateApiRequest, hasScope }
    "src/lib/auth/app-passwords" --> src.lib.jmap.handler { allowAppPasswordGuess, basicPassword }
    src.lib.jmap.constants --> src.lib.jmap.handler { LIMITS }
    src.lib.jmap.errors --> src.lib.jmap.handler { JmapError, corsHeaders, problemResponse }
    src.lib.jmap.blobs --> src.lib.jmap.handler { readBlob, storeUpload }
    "src/lib/jmap/request-utils" --> src.lib.jmap.handler {
        parsePingSeconds,
        tryDecodeURIComponent,
    }
    src.lib.jmap.processor --> src.lib.jmap.handler {
        processRequest,
        sessionState,
        validateRequest,
    }
    src.lib.jmap.session --> src.lib.jmap.handler { buildSession }
    src.lib.jmap.state --> src.lib.jmap.handler { getEmailState, getMailboxState }
    "src/lib/jmap/types.d" --> src.lib.jmap.handler { JmapContext }
    "src/lib/jmap/types.d" --> src.lib.jmap.errors { JmapMethodError }
    "src/lib/api/key-auth-types.d" --> "src/lib/jmap/types.d" { ApiAuthResult }
    src.db.index --> "src/lib/jmap/types.d" { AppDatabase }
    src.lib.jmap.changes --> "src/lib/jmap/types.d" { ChangeScope }
    src.db.index --> src.lib.jmap.changes { AppDatabase, getDb }
    src.db.schema.index --> src.lib.jmap.changes {
        jmapChangeFloor,
        jmapChanges,
        mailboxPromotionSettings,
        messages,
    }
    src.db.sql --> src.lib.jmap.changes { greatest }
    "src/lib/email/draft-access" --> src.lib.jmap.changes { DRAFT_FILTER_PARAMS, draftsVisibleTo }
    "src/lib/database-errors" --> src.lib.jmap.changes { isMissingTableError }
    src.lib.jmap.access --> src.lib.jmap.changes { listFoldersByMailbox, listJmapMailboxes }
    src.lib.jmap.ids --> src.lib.jmap.changes { SYSTEM_ROLES, encodeMailboxRef }
    "src/lib/jmap/types.d" --> src.lib.jmap.changes { AccessibleMailbox, JmapContext }
    "src/lib/jmap/changes-utils" --> src.lib.jmap.changes {
        coalesceChanges,
        formatState,
        parseState,
    }
    src.db.schema.index --> src.lib.jmap.access { folders, mailboxes }
    src.lib.mailboxes.access --> src.lib.jmap.access { listAccessibleMailboxes }
    "src/lib/mailboxes/domain-addresses" --> src.lib.jmap.access { getMailboxDomainAddresses }
    "src/lib/jmap/types.d" --> src.lib.jmap.access { AccessibleMailbox, JmapContext }
    src.db.index --> "src/lib/mailboxes/domain-addresses" { AppDatabase }
    src.db.schema.index --> "src/lib/mailboxes/domain-addresses" {
        domains,
        mailboxAliases,
        mailboxes,
    }
    "src/lib/cloudflare-api" --> "src/lib/mailboxes/domain-addresses" {
        EmailRoutingRuleCache,
        deleteEmailRoutingRuleForAddress,
        ensureEmailRoutingRuleToWorker,
    }
    "src/lib/email/recipient-address" --> "src/lib/mailboxes/domain-addresses" {
        normalizeRecipientLocalPart,
        parseRecipientAddress,
    }
    "src/lib/mailboxes/domain-addresses-types.d" --> "src/lib/mailboxes/domain-addresses" {
        MailboxDomainAddressInput,
    }
    "src/lib/cloudflare-api.types.d" --> "src/lib/mailboxes/domain-addresses" {
        CfEmailRoutingRuleChange,
    }
    "src/lib/cloudflare-api.types.d" --> "src/lib/cloudflare-api" {
        CfDnsRecord,
        CfEmailRoutingRule,
        CfEmailRoutingRuleChange,
        CfResponse,
        CfResultInfo,
        CfSendingSubdomain,
    }
    "src/lib/cloudflare-api-utils" --> "src/lib/cloudflare-api" {
        formatCloudflareError,
        getCloudflareAuth,
        getCloudflareAuthHeaders,
        getCloudflareAuthHint,
        getEmailWorkerName,
    }
    "src/lib/cloudflare-api-error" --> "src/lib/cloudflare-api" { CloudflareApiError }
    src.lib.domains.utils --> "src/lib/cloudflare-api" { getZoneLookupCandidates }
    "src/lib/cloudflare-api.types.d" --> "src/lib/cloudflare-api-utils" { CfApiError, CfAuth }
    "src/lib/cloudflare-api.types.d" --> "src/lib/cloudflare-api-error" { CfApiError }
    "src/lib/jmap/types.d" --> src.lib.jmap.ids { MailboxRef, SystemRole }
    src.db.schema.index --> src.lib.jmap.blobs { messageAttachments, messages }
    "src/lib/email/draft-access" --> src.lib.jmap.blobs { isOthersDraft }
    src.lib.ids --> src.lib.jmap.blobs { newId }
    src.lib.jmap.constants --> src.lib.jmap.blobs { LIMITS }
    src.lib.jmap.ids --> src.lib.jmap.blobs { decodeBlobId, uploadBlobId }
    src.lib.jmap.access --> src.lib.jmap.blobs { listAccessibleMailboxIdSet }
    "src/lib/jmap/types.d" --> src.lib.jmap.blobs { JmapContext }
    src.lib.jmap.constants --> src.lib.jmap.processor {
        CAPABILITY_CORE,
        CAPABILITY_MAIL,
        CAPABILITY_SUBMISSION,
        LIMITS,
    }
    src.lib.jmap.errors --> src.lib.jmap.processor { JmapError }
    src.lib.jmap.mailboxes --> src.lib.jmap.processor {
        mailboxChanges,
        mailboxGet,
        mailboxQuery,
        mailboxSet,
    }
    src.lib.jmap.emails --> src.lib.jmap.processor {
        emailChanges,
        emailGet,
        emailImport,
        emailQuery,
        emailQueryChanges,
        emailSet,
        emailUnsupported,
        searchSnippetGet,
        threadChanges,
        threadGet,
    }
    src.lib.jmap.identities --> src.lib.jmap.processor {
        emailSubmissionChanges,
        emailSubmissionGet,
        emailSubmissionQuery,
        emailSubmissionSet,
        identityChanges,
        identityGet,
        identitySet,
    }
    src.lib.jmap.state --> src.lib.jmap.processor { getEmailState }
    "src/lib/jmap/types.d" --> src.lib.jmap.processor {
        JmapContext,
        JmapInvocation,
        JmapMethodHandler,
        JmapRequest,
        JmapResponse,
    }
    src.lib.jmap.changes --> src.lib.jmap.mailboxes { mailboxChangesSince }
    src.db.schema.index --> src.lib.jmap.mailboxes { folders, messages }
    "src/lib/email/draft-access" --> src.lib.jmap.mailboxes { draftsVisibleTo }
    src.lib.ids --> src.lib.jmap.mailboxes { newId }
    src.lib.jmap.errors --> src.lib.jmap.mailboxes { JmapError }
    src.lib.jmap.ids --> src.lib.jmap.mailboxes {
        SYSTEM_ROLES,
        decodeMailboxRef,
        encodeMailboxRef,
        roleToStatus,
    }
    src.lib.jmap.state --> src.lib.jmap.mailboxes { getMailboxState }
    "src/lib/jmap/types.d" --> src.lib.jmap.mailboxes {
        AccessibleMailbox,
        JmapContext,
        JmapMethodHandler,
        SystemRole,
    }
    src.lib.jmap.access --> src.lib.jmap.mailboxes { listFoldersByMailbox, listJmapMailboxes }
    "src/lib/jmap/types.d" --> src.lib.jmap.state { JmapContext }
    src.lib.jmap.changes --> src.lib.jmap.state { currentChangeScope }
    src.lib.jmap.changes --> src.lib.jmap.emails { emailChangesSince, threadChangesSince }
    src.db.schema.index --> src.lib.jmap.emails { folders, messages }
    "src/lib/email/draft-access" --> src.lib.jmap.emails {
        DRAFT_FILTER_PARAMS,
        draftsVisibleTo,
        logMessageHidden,
        privateDraftForStatus,
    }
    src.lib.ids --> src.lib.jmap.emails { newId }
    src.lib.email.parse --> src.lib.jmap.emails { buildSnippet, parseRawMime }
    src.lib.email.sender --> src.lib.jmap.emails { getAuthorizedSenderAddress }
    src.lib.email.address --> src.lib.jmap.emails { formatEmailAddress, joinEmailAddressList }
    src.lib.email.threading --> src.lib.jmap.emails { resolveThreadId }
    src.lib.email.attachments --> src.lib.jmap.emails { storeMessageAttachments }
    "src/lib/email/message-cleanup" --> src.lib.jmap.emails { deleteMessageWithObjects }
    src.lib.jmap.constants --> src.lib.jmap.emails { KEYWORD_FLAGGED, KEYWORD_SEEN, LIMITS }
    src.lib.jmap.errors --> src.lib.jmap.emails { JmapError, invalidArguments }
    src.lib.jmap.ids --> src.lib.jmap.emails { decodeBlobId, decodeMailboxRef, roleToStatus }
    "src/lib/jmap/email-objects" --> src.lib.jmap.emails {
        buildEmailObject,
        loadAttachmentsByMessage,
        resolveHeaderProperty,
    }
    "src/lib/jmap/email-import-utils" --> src.lib.jmap.emails {
        importFlags,
        parseReceivedAt,
        resolveDraftsMailbox,
    }
    "src/lib/jmap/email-query" --> src.lib.jmap.emails {
        filterToSql,
        mailboxRefCondition,
        sortToSql,
    }
    src.lib.jmap.state --> src.lib.jmap.emails { getEmailState }
    src.lib.promotions.settings --> src.lib.jmap.emails { loadPromotionModes }
    src.lib.jmap.access --> src.lib.jmap.emails { listAccessibleMailboxIdSet, listJmapMailboxes }
    src.lib.jmap.blobs --> src.lib.jmap.emails { deleteUpload, readUpload, storeRawDraftMime }
    "src/lib/jmap/types.d" --> src.lib.jmap.emails {
        Comparator,
        EmailAddressObject,
        Filter,
        JmapContext,
        JmapMethodHandler,
        JmapSetError,
        MailboxRef,
    }
    "src/lib/email/attachment-types.d" --> src.lib.jmap.emails { AttachmentContent }
    src.db.index --> src.lib.email.sender { getDb }
    src.db.schema.index --> src.lib.email.sender { domains, mailboxes, users }
    src.lib.mailboxes.access --> src.lib.email.sender { getMailboxAccessLevel }
    src.lib.email.address --> src.lib.email.sender { formatEmailAddress, getEmailAddress }
    "src/lib/mailboxes/domain-addresses" --> src.lib.email.sender {
        getMailboxAliasForAddress,
        getMailboxDomainAddresses,
    }
    "src/lib/profile/identity-utils" --> src.lib.email.sender { resolveMailboxDisplayName }
    src.db.index --> "src/lib/email/message-cleanup" { AppDatabase }
    src.db.schema.index --> "src/lib/email/message-cleanup" { messages }
    src.lib.email.attachments --> "src/lib/email/message-cleanup" { deleteMessageAttachmentObjects }
    src.db.schema.index --> "src/lib/jmap/email-objects" { messageAttachments, messages }
    src.lib.email.address --> "src/lib/jmap/email-objects" {
        parseEmailAddressParts,
        splitEmailAddressList,
    }
    "src/lib/email/reply-content-utils" --> "src/lib/jmap/email-objects" { htmlToReadableText }
    src.lib.promotions.settings --> "src/lib/jmap/email-objects" { PromotionMode }
    src.lib.jmap.constants --> "src/lib/jmap/email-objects" {
        KEYWORD_DRAFT,
        KEYWORD_FLAGGED,
        KEYWORD_PROMOTION,
        KEYWORD_SEEN,
    }
    src.lib.jmap.ids --> "src/lib/jmap/email-objects" {
        attachmentBlobId,
        encodeMailboxRef,
        messageBlobId,
        statusToRole,
    }
    "src/lib/jmap/types.d" --> "src/lib/jmap/email-objects" {
        EmailAddressObject,
        EmailBodyPart,
        JmapContext,
    }
    src.db.index --> src.lib.promotions.settings { getDb }
    src.db.schema.index --> src.lib.promotions.settings { mailboxPromotionSettings, messages }
    src.db.sql --> src.lib.promotions.settings { matchNothing }
    "src/lib/database-errors" --> src.lib.promotions.settings { isMissingTableError }
    src.lib.jmap.constants --> "src/lib/jmap/email-import-utils" { KEYWORD_FLAGGED, KEYWORD_SEEN }
    src.lib.jmap.ids --> "src/lib/jmap/email-import-utils" { decodeMailboxRef }
    "src/lib/jmap/types.d" --> "src/lib/jmap/email-import-utils" { JmapSetError }
    src.db.schema.index --> "src/lib/jmap/email-query" {
        mailboxPromotionSettings,
        messageAttachments,
        messages,
    }
    src.db.sql --> "src/lib/jmap/email-query" {
        concatText,
        containsLike,
        escapeLike,
        insensitiveLike,
        matchEverything,
        matchNothing,
    }
    src.lib.jmap.constants --> "src/lib/jmap/email-query" {
        KEYWORD_DRAFT,
        KEYWORD_FLAGGED,
        KEYWORD_PROMOTION,
        KEYWORD_SEEN,
    }
    src.lib.jmap.errors --> "src/lib/jmap/email-query" { invalidArguments, unsupportedFilter }
    src.lib.email.threading --> "src/lib/jmap/email-query" { normalizeMessageId }
    src.lib.jmap.ids --> "src/lib/jmap/email-query" { decodeMailboxRef, roleToStatus }
    "src/lib/jmap/types.d" --> "src/lib/jmap/email-query" {
        Comparator,
        Filter,
        FilterCondition,
        MailboxRef,
    }
    src.db.schema.index --> src.lib.jmap.identities { agentDraftMetadata, messages }
    src.lib.email.send --> src.lib.jmap.identities { sendEmail }
    "src/lib/deliverability/suppression-utils" --> src.lib.jmap.identities {
        SuppressedRecipientError,
        suppressedSubmissionError,
    }
    src.lib.email.attachments --> src.lib.jmap.identities { loadMessageAttachmentContents }
    "src/lib/email/message-cleanup" --> src.lib.jmap.identities { deleteMessageWithObjects }
    src.lib.jmap.ids --> src.lib.jmap.identities { decodeIdentityId, identityId }
    src.lib.jmap.access --> src.lib.jmap.identities { listJmapMailboxes, listSendableAddresses }
    src.lib.jmap.state --> src.lib.jmap.identities { getEmailState }
    src.lib.jmap.errors --> src.lib.jmap.identities { JmapError }
    "src/lib/jmap/types.d" --> src.lib.jmap.identities { JmapContext, JmapMethodHandler }
    src.db.index --> src.lib.email.send { getDb }
    src.db.schema.index --> src.lib.email.send {
        conversationNotes,
        mailboxes,
        messages,
        outboundJobs,
    }
    src.lib.ids --> src.lib.email.send { newId }
    src.lib.email.parse --> src.lib.email.send { buildSnippet }
    src.lib.email.webhooks --> src.lib.email.send { dispatchWebhooks }
    src.lib.contacts.service --> src.lib.email.send { upsertContactsFromAddresses }
    src.lib.email.sender --> src.lib.email.send { getAuthorizedSenderAddress }
    src.lib.email.address --> src.lib.email.send {
        getEmailAddress,
        getEmailAddressList,
        joinEmailAddressList,
        splitEmailAddressList,
    }
    src.lib.email.threading --> src.lib.email.send {
        formatMessageIdHeader,
        normalizeMessageId,
        parseMessageIdList,
    }
    src.lib.mailboxes.audit --> src.lib.email.send { createAuditLog }
    src.lib.email.attachments --> src.lib.email.send {
        loadMessageAttachmentContents,
        storeMessageAttachments,
        validateAttachments,
    }
    "src/lib/email/attachment-types.d" --> src.lib.email.send { AttachmentContent }
    "src/lib/email/attachment-policy" --> src.lib.email.send { getOutboundAttachmentMaxMb }
    "src/lib/email/outbound-provider" --> src.lib.email.send {
        getOutboundProviderConfig,
        sendThroughProvider,
    }
    "src/lib/email/cloud-attachment-utils" --> src.lib.email.send { prepareOutboundAttachments }
    "src/lib/tracking/open-tracking" --> src.lib.email.send {
        ensureTrackingToken,
        getTrackingHostForSender,
    }
    "src/lib/follow-ups/service" --> src.lib.email.send { setFollowUp }
    "src/lib/tracking/open-tracking-utils" --> src.lib.email.send {
        buildTrackingPixelUrl,
        injectTrackingPixel,
        resolveTrackingOrigin,
    }
    src.lib.compose.preferences --> src.lib.email.send { getComposePreferences }
    "src/lib/mailboxes/domain-addresses" --> src.lib.email.send { getMailboxDomainAddresses }
    src.lib.deliverability.suppression --> src.lib.email.send {
        assertNoSuppressedRecipients,
        dropSuppressedRecipients,
    }
    src.db.index --> src.lib.email.webhooks { AppDatabase, getDb }
    src.db.schema.index --> src.lib.email.webhooks { webhookDeliveries, webhooks }
    src.lib.ids --> src.lib.email.webhooks { newId }
    "src/lib/security/public-url" --> src.lib.email.webhooks {
        PUBLIC_HTTPS_URL_MESSAGE,
        assertResolvesPublic,
        isPublicHttpsUrl,
    }
    src.db.index --> src.lib.contacts.service { getDb }
    "src/lib/db-params" --> src.lib.contacts.service { selectInBatches }
    src.db.schema.index --> src.lib.contacts.service { contacts, domains, routingRules }
    src.lib.email.address --> src.lib.contacts.service {
        getFirstEmailAddressEntry,
        normalizeEmailAddress,
    }
    "src/lib/contacts/types.d" --> src.lib.contacts.service {
        BlockContactInput,
        ContactCard,
        ContactDisplayName,
        ContactInput,
        MessageContactNames,
    }
    "src/lib/email/address-types.d" --> src.lib.contacts.service { ContactSource }
    "src/lib/spam/domain-utils" --> src.lib.contacts.service {
        isMultiPartSuffix,
        isSharedMailDomain,
        registrableDomain,
    }
    src.lib.contacts.utils --> src.lib.contacts.service {
        getContactId,
        getContactNameFromAddress,
        getPartyDisplayName,
    }
    src.lib.contacts.gravatar --> src.lib.contacts.service { importGravatarAvatar }
    src.db.schema.index --> "src/lib/contacts/types.d" { contacts }
    "src/lib/email/address-types.d" --> "src/lib/contacts/types.d" { ContactSource }
    "src/lib/contacts/types.d" --> src.lib.contacts.utils { ContactNameSource }
    src.lib.email.address --> src.lib.contacts.utils {
        getEmailDisplayName,
        normalizeEmailAddress,
        parseEmailAddressParts,
    }
    src.lib.contacts.avatar --> src.lib.contacts.gravatar { contactAvatarKeyFor }
    "src/lib/avatar-images" --> src.lib.contacts.gravatar { avatarPreviewKeyFor }
    src.db.index --> src.lib.mailboxes.audit { getDb }
    src.db.schema.index --> src.lib.mailboxes.audit { auditLogs }
    src.lib.ids --> src.lib.mailboxes.audit { newId }
    "src/lib/mailboxes/types.d" --> src.lib.mailboxes.audit { AuditLogInput }
    src.db.index --> "src/lib/email/outbound-provider" { getDb }
    src.db.schema.index --> "src/lib/email/outbound-provider" { appSettings, domains }
    src.lib.aws.config --> "src/lib/email/outbound-provider" { requireAwsConfig }
    src.lib.aws.ses --> "src/lib/email/outbound-provider" { sendSesEmail }
    src.lib.email.address --> "src/lib/email/outbound-provider" { getEmailAddress }
    "src/lib/email/resend-api" --> "src/lib/email/outbound-provider" {
        ResendClient,
        fetchSentMessageId,
        resendClient,
        resendOmittedHeaders,
        resendSetsMessageId,
    }
    "src/lib/email/outbound-provider-types.d" --> "src/lib/email/outbound-provider" {
        OutboundProviderConfig,
        OutboundProviderMessage,
        ResendKeyStatus,
    }
    src.db.index --> src.lib.aws.config { getDb }
    src.db.schema.index --> src.lib.aws.config { appSettings }
    "src/lib/aws/aws-types.d" --> src.lib.aws.config { AwsConfig, AwsConfigStatus }
    src.lib.aws.client --> src.lib.aws.ses { AwsError, awsJson, awsQuery }
    src.lib.aws.xml --> src.lib.aws.ses { xmlBlocks, xmlTag, xmlTags }
    "src/lib/aws/aws-types.d" --> src.lib.aws.ses { AwsConfig, SesIdentityStatus }
    "src/lib/email/attachment-types.d" --> "src/lib/email/cloud-attachment-utils" {
        AttachmentContent,
    }
    "src/lib/email/attachment-limits" --> "src/lib/email/cloud-attachment-utils" {
        planAttachmentDelivery,
    }
    "src/lib/email/outbound-provider-types.d" --> "src/lib/email/cloud-attachment-utils" {
        SendingProvider,
    }
    "src/lib/email/shared-attachments" --> "src/lib/email/cloud-attachment-utils" {
        SHARED_ATTACHMENT_LINK_DAYS,
        getOrCreateSharedAttachmentUrl,
    }
    "src/lib/email/shared-file-notice" --> "src/lib/email/cloud-attachment-utils" {
        SharedFileLink,
        sharedFileNotice,
    }
    src.lib.i18n.utils --> "src/lib/email/cloud-attachment-utils" {
        Translator,
        createTranslator,
        defaultTranslator,
        loadMessages,
        resolveLocale,
    }
    src.db.index --> "src/lib/email/shared-attachments" { getDb }
    src.db.schema.index --> "src/lib/email/shared-attachments" { sharedAttachmentLinks }
    src.lib.ids --> "src/lib/email/shared-attachments" { newId }
    src.lib.i18n.utils ++> "src/lib/email/shared-file-notice" { defaultTranslator }
    src.lib.email.address --> "src/lib/tracking/open-tracking" { getEmailAddress }
    src.db.index --> "src/lib/tracking/open-tracking" { getDb }
    src.db.schema.index --> "src/lib/tracking/open-tracking" {
        domainTrackingHosts,
        domains,
        messageOpens,
        messageTracking,
        messages,
    }
    src.lib.ids --> "src/lib/tracking/open-tracking" { newId }
    "src/lib/tracking/open-tracking-utils" --> "src/lib/tracking/open-tracking" {
        MAX_STORED_OPENS,
        classifyOpen,
        createTrackingToken,
        isDuplicateOpen,
    }
    "src/lib/tracking/types.d" --> "src/lib/tracking/open-tracking" { MessageTrackingSummary }
    "src/lib/database-errors" --> "src/lib/tracking/open-tracking" { isMissingTableError }
    "src/lib/tracking/types.d" --> "src/lib/tracking/open-tracking-utils" {
        OpenClassification,
        OpenRequestInfo,
    }
    src.db.index --> "src/lib/follow-ups/service" { getDb }
    src.db.schema.index --> "src/lib/follow-ups/service" { followUps, messages }
    "src/lib/database-errors" --> "src/lib/follow-ups/service" { isMissingTableError }
    src.lib.ids --> "src/lib/follow-ups/service" { newId }
    "src/lib/follow-ups/follow-up-utils" --> "src/lib/follow-ups/service" { followUpDueAt }
    "src/lib/follow-ups/types.d" --> "src/lib/follow-ups/service" { DueFollowUp, MessageFollowUp }
    src.db.index --> src.lib.compose.preferences { getDb }
    src.db.schema.index --> src.lib.compose.preferences { userComposePreferences }
    "src/lib/database-errors" --> src.lib.compose.preferences {
        isMissingColumnError,
        isMissingTableError,
    }
    "src/lib/compose/compose-utils" --> src.lib.compose.preferences {
        DEFAULT_UNDO_SEND_SECONDS,
        parseUndoSendSeconds,
    }
    "src/lib/compose/types.d" --> src.lib.compose.preferences { ComposePreferences }
    src.db.index --> src.lib.deliverability.suppression { getDb }
    src.db.schema.index --> src.lib.deliverability.suppression {
        appSettings,
        domains,
        emailSuppressions,
        messages,
    }
    src.lib.email.address --> src.lib.deliverability.suppression { getEmailAddressList }
    src.lib.ids --> src.lib.deliverability.suppression { newId }
    src.lib.email.sender --> src.lib.deliverability.suppression { getAuthorizedSenderAddress }
    src.lib.deliverability.dsn --> src.lib.deliverability.suppression { parseDeliveryStatus }
    "src/lib/deliverability/suppression-utils" --> src.lib.deliverability.suppression {
        MAX_SUPPRESSION_DETAIL,
        SuppressedRecipientError,
        SuppressionEntry,
        SuppressionMode,
        SuppressionReason,
        SuppressionSource,
        addressDomain,
        cleanAddress,
        filterSuppressed,
    }
    src.lib.email.address --> "src/lib/deliverability/suppression-utils" {
        getEmailAddress,
        normalizeEmailAddress,
        splitEmailAddressList,
    }
    src.lib.jmap.constants --> src.lib.jmap.session {
        CAPABILITY_CORE,
        CAPABILITY_MAIL,
        CAPABILITY_SUBMISSION,
        LIMITS,
    }
    "src/lib/jmap/types.d" --> src.lib.jmap.session { JmapContext }
    "src/lib/i18n/types.d" --> "src/app/types.d" { TranslationKey }
    src.components.icons --> "src/app/types.d" { LucideIcon }
    src.components.ui.button --> "src/app/types.d" { ButtonProps }
    "src/components/mailbox-selector-types.d" --> "src/app/types.d" { MailboxSelectorUser }
    src.lib.utils --> src.components.ui.button { cn }
    "src/components/mailbox-provider" --> "src/components/mailbox-selector-types.d" {
        MailboxOption,
    }
    "src/components/mailbox-provider-utils" --> "src/components/mailbox-provider" {
        SELECTED_MAILBOX_STORAGE_KEY,
        clearMailboxesCache,
        fetchMailboxOptions,
        isIdentityMailbox,
    }
    src.lib.auth.client --> "src/components/mailbox-provider" {
        AUTH_SESSION_CHANGED_EVENT,
        getClientSessionToken,
    }
    "src/lib/profile/name-client" --> "src/components/mailbox-provider" {
        PROFILE_NAME_CHANGED_EVENT,
    }
    "src/lib/profile/avatar-client" --> "src/components/mailbox-provider" {
        PROFILE_AVATAR_CHANGED_EVENT,
    }
    "src/lib/auth/client-types.d" --> "src/components/mailbox-provider" { AuthSessionChangedDetail }
    "src/lib/profile/types.d" --> "src/components/mailbox-provider" { ProfileNameChangedDetail }
    src.lib.auth.client --> "src/components/mailbox-provider-utils" {
        authFetch,
        getClientSessionToken,
    }
    "src/components/mailbox-provider" --> "src/components/mailbox-provider-utils" { MailboxOption }
    src.lib.time.utils --> src.lib.auth.client { getUserTimeZone }
    src.lib.time.client --> src.lib.auth.client { clearUserTimeZonePreference }
    "src/lib/auth/client-types.d" --> src.lib.auth.client {
        AuthFetchOptions,
        AuthSessionChangedDetail,
        AuthSessionResponse,
    }
    "src/lib/time/types.d" --> src.lib.time.utils { ZonedDay }
    src.lib.time.utils --> src.lib.time.client { clearUserTimeZoneCache }
    "src/lib/profile/types.d" --> "src/lib/profile/name-client" { ProfileNameChangedDetail }
    "src/lib/profile/types.d" --> "src/lib/profile/avatar-client" { ProfileAvatarChangedDetail }
    "src/lib/i18n/types.d" --> "src/components/accounts/account-settings-nav-types.d" {
        TranslationKey,
    }
    src.components.icons --> "src/components/auth/types.d" { LucideIcon }
    "src/lib/branding/types.d" --> "src/components/branding-provider-types.d" { Branding }
    src.components.icons --> "src/components/components-nav-types.d" { LucideIcon }
    "src/lib/i18n/types.d" --> "src/components/compose/rich-text-editor-types.d" { TranslationKey }
    "src/lib/i18n/types.d" --> "src/components/compose/schedule-send-types.d" { TranslationKey }
    "src/lib/contacts/details-types.d" --> "src/components/contacts/contact-details-types.d" {
        ContactDetailsData,
    }
    "src/lib/email/address-types.d" --> "src/components/contacts/contacts-page-types.d" {
        ContactSource,
    }
    "src/lib/i18n/types.d" --> "src/components/language-provider-types.d" { Locale }
    src.lib.i18n.utils --> "src/components/language-provider-types.d" { Translator }
    "src/lib/licenses/types.d" --> "src/components/license-indicator-types.d" { LicenseStatus }
    "src/lib/i18n/types.d" --> "src/components/message-actions/types.d" { TranslationKey }
    "src/app/api/messages/bulk/types.d" --> "src/components/message-actions/types.d" {
        BulkMessageAction,
    }
    "src/hooks/types.d" --> "src/components/message-actions/types.d" { Message, MessageDirection }
    src.components.icons --> "src/components/message-actions/types.d" { IconNode }
    "src/lib/i18n/types.d" --> "src/components/message-attachment-card-types.d" { TranslationKey }
    "src/app/(dashboard)/inbox/[messageId]/types.d" --> "src/components/message-attachment-card-types.d" {
        MessageAttachment,
    }
    src.components.icons --> "src/components/message-attachment-card-types.d" { LucideIcon }
    "src/app/(dashboard)/inbox/[messageId]/types.d" --> "src/components/message-attachment-viewer-types.d" {
        MessageAttachment,
    }
    "src/lib/notes/types.d" --> "src/components/messages/conversation-notes-types.d" {
        ConversationNote,
    }
    "src/hooks/types.d" --> "src/components/messages/conversation-thread-types.d" { ThreadMessage }
    "src/app/api/messages/navigation/types.d" --> "src/components/messages/message-detail-navigation-types.d" {
        MessageNavigationEntry,
    }
    "src/components/messages/types.d" --> "src/components/messages/message-detail-navigation-types.d" {
        MessageFolderConfig,
    }
    "src/lib/i18n/types.d" --> "src/components/messages/types.d" { TranslationKey }
    src.components.icons --> "src/components/messages/types.d" { LucideIcon }
    "src/hooks/types.d" --> "src/components/messages/types.d" { Message, MessageFolder }
    "src/app/api/messages/bulk/types.d" --> "src/components/messages/types.d" { BulkMessageAction }
    "src/hooks/types.d" --> "src/components/messages/message-details-types.d" { Message }
    "src/components/messages/message-details-types.d" --> "src/components/messages/sender-check-types.d" {
        MessageDetailsMessage,
    }
    "src/lib/spam/types.d" --> "src/components/messages/spam-score-details-types.d" { SpamSignal }
    "src/hooks/types.d" --> "src/components/messages/thread-message-actions-types.d" {
        ThreadMessage,
    }
    "src/hooks/message-realtime-types.d" --> "src/components/new-message-popup-types.d" {
        NewMessageEvent,
    }
    "src/lib/email/reply-content-types.d" --> "src/components/previous-message-types.d" {
        QuotedEmailContent,
    }
    "src/lib/import/jobs-types.d" --> "src/components/settings/import-messages-types.d" {
        ImportJobSummary,
    }
    "src/lib/i18n/types.d" --> "src/components/settings/settings-nav-types.d" { TranslationKey }
    "src/lib/import/takeout-data-types.d" --> "src/components/settings/takeout-calendar-card-types.d" {
        CalendarSource,
    }
    "src/lib/import/takeout-calendar-types.d" --> "src/components/settings/takeout-calendar-card-types.d" {
        CalendarRunSummary,
    }
    "src/lib/import/zip-types.d" --> "src/lib/import/takeout-data-types.d" { ZipEntry }
    "src/lib/calendar/import-store-types.d" --> "src/lib/import/takeout-calendar-types.d" {
        CalendarImportSummary,
    }
    "src/lib/calendar/ics-import-types.d" --> "src/lib/calendar/import-store-types.d" {
        ImportGroup,
    }
    src.lib.calendar.invite --> "src/lib/calendar/ics-import-types.d" { InviteRepeat }
    src.lib.time.utils --> src.lib.calendar.invite {
        dateFromZonedFields,
        normalizeTimeZone,
        zonedDateFields,
    }
    src.lib.calendar.ics --> src.lib.calendar.invite {
        MAX_ICS_ADDRESS,
        escapeIcsText,
        formatIcsUtc,
        isIcsAddress,
        joinIcsLines,
    }
    "src/lib/calendar/reminder-utils" --> src.lib.calendar.invite { normalizeReminderMinutes }
    "src/lib/calendar/tool-occurrences" --> "src/lib/calendar/reminder-utils" { expandToolEvents }
    src.db.schema.index --> "src/lib/calendar/reminder-utils" { calendarEvents }
    src.lib.time.utils --> "src/lib/calendar/tool-occurrences" {
        dateFromZonedFields,
        normalizeTimeZone,
        zonedDateFields,
    }
    src.lib.calendar.recurrence --> "src/lib/calendar/tool-occurrences" {
        parseCalendarRepeatDays,
        parseExcludedOccurrences,
    }
    src.db.schema.index --> "src/lib/calendar/tool-occurrences" { calendarEvents }
    "src/lib/calendar/types.d" --> src.lib.calendar.recurrence { CalendarRepeat }
    "src/lib/import/takeout-data-types.d" --> "src/components/settings/takeout-contacts-card-types.d" {
        ContactSource,
    }
    "src/lib/import/takeout-contacts-types.d" --> "src/components/settings/takeout-contacts-card-types.d" {
        ContactRunSummary,
    }
    "src/lib/i18n/types.d" --> "src/lib/import/takeout-contacts-types.d" { TranslationKey }
    "src/lib/contacts/import-store-types.d" --> "src/lib/import/takeout-contacts-types.d" {
        ContactImportSummary,
    }
    "src/lib/contacts/types.d" --> "src/lib/contacts/import-store-types.d" { ContactNameSource }
    "src/lib/contacts/vcard-types.d" --> "src/lib/contacts/import-store-types.d" { ImportedContact }
    "src/lib/contacts/details-types.d" --> "src/lib/contacts/vcard-types.d" { ContactDetailsData }
    "src/lib/import/takeout-data-types.d" --> "src/components/settings/takeout-drive-card-types.d" {
        DriveScan,
    }
    "src/lib/import/gmail-takeout-types.d" --> "src/components/settings/takeout-import-types.d" {
        TakeoutImportSummary,
    }
    "src/lib/promotions/subscriptions-ui-types.d" --> "src/components/subscriptions/subscription-parts-types.d" {
        SubscriptionCategory,
        SubscriptionRowAction,
        SubscriptionRowData,
        SubscriptionRowView,
    }
    "src/lib/auth/types.d" --> "src/lib/agent/types.d" { SessionUser }
    "src/lib/agent/provider-types.d" --> "src/lib/ai/usage-types.d" { AgentModelRates }
    src.db.schema.index --> "src/lib/calendar/api-auth-types.d" { users }
    "src/lib/api/key-auth-types.d" --> "src/lib/calendar/api-auth-types.d" { ApiAuthResult }
    src.lib.calendar.invite --> "src/lib/calendar/invite-types.d" { InviteResponse }
    "src/lib/auth/types.d" --> "src/lib/calendar/tool-types.d" { SessionUser }
    "src/lib/aws/ses-receiving-types.d" --> "src/lib/domains/resend-receiving-types.d" {
        ReceivingStep,
    }
    src.db.schema.index --> "src/lib/domains/types.d" { domains }
    "src/lib/cloudflare-api.types.d" --> "src/lib/domains/types.d" {
        CfDnsRecord,
        CfEmailRoutingRule,
    }
    "src/lib/drive/import-types.d" --> "src/lib/drive/import-store-types.d" { ImportFilePlan }
    src.db.schema.index --> "src/lib/drive/types.d" { driveItems }
    "src/lib/spam/types.d" --> "src/lib/email/intake-types.d" { ProviderVerdicts }
    "src/app/(drive)/drive-upload" --> "src/lib/import/takeout-drive-types.d" { DriveUploadSource }
    src.lib.auth.client --> "src/app/(drive)/drive-upload" { authFetch, getAuthHeaders }
    "src/lib/import/takeout-calendar-utils" --> "src/app/(drive)/drive-upload" {
        parseRetryAfter,
        sleepFor,
    }
    "src/lib/calendar/ics-import" --> "src/lib/import/takeout-calendar-utils" {
        MAX_IMPORT_EVENTS,
        parseIcsEventGroup,
        splitIcsEvents,
    }
    "src/lib/import/takeout-calendar-types.d" --> "src/lib/import/takeout-calendar-utils" {
        CalendarPost,
        CalendarRunOptions,
        CalendarRunSettings,
        CalendarRunSummary,
    }
    src.lib.time.utils --> "src/lib/calendar/ics-import" { normalizeTimeZone, zonedDateFields }
    src.lib.calendar.ics --> "src/lib/calendar/ics-import" { isIcsAddress }
    "src/lib/calendar/ics-import-types.d" --> "src/lib/calendar/ics-import" {
        ImportEvent,
        ImportGroup,
        ImportOptions,
        SplitIcsResult,
    }
    src.lib.calendar.invite --> "src/lib/calendar/ics-import" {
        InviteRepeat,
        Property,
        addZonedDays,
        inviteRepeat,
        parseIcsDate,
        parseIcsDuration,
        parseProperty,
        unescapeText,
    }
    "src/lib/calendar/reminder-utils" --> "src/lib/calendar/ics-import" { normalizeReminderMinutes }
    "src/lib/auth/types.d" --> "src/lib/mcp/types.d" { SessionUser }
    "src/hooks/types.d" --> "src/lib/messages/detail-cache-types.d" { Message }
    src.db.schema.index --> "src/lib/seed-types.d" { mailboxes }
    tests.helpers.fixtures --> "tests/account-password-race.test" {
        concurrentPasswordWrite,
        installSqlite,
        loadFixture,
    }
    tests.helpers.fixtures --> "tests/admin-general-dav.test" { installSqlite, loadFixture }
    "tests/helpers/real-db" --> "tests/admin-key-demotion.test" { loadApp }
    src.components.agent.utils --> "tests/agent-draft-actions.test" { uniqueAgentDraftActions }
    src.lib.i18n.utils --> src.components.agent.utils { Translator }
    "src/components/agent/types.d" --> src.components.agent.utils {
        AgentActionProposal,
        AgentDraftAction,
        AgentEmailReference,
        AgentEvent,
        AgentMessage,
        AgentTurn,
        QueuedAgentMessage,
    }
    "src/lib/push/native-crypto" --> "tests/apns-key-import.test" { importApnsKey }
    tests.helpers.fixtures --> "tests/app-password-route.test" { installSqlite, loadFixture }
    tests.helpers.fixtures --> "tests/app-passwords-utils.test" { loadFixture }
    "tests/helpers/dom-component" --> "tests/compose-ui-behavior.test" { loadComponent }
    "tests/helpers/real-db" --> "tests/contacts-seen-like.test" { loadApp, sharedMailboxSeed }
    "tests/conversation-page-utils" --> "tests/conversation-page.test" {
        at,
        createConversationFixture,
    }
    "tests/helpers/real-db" --> "tests/d1-param-budget.test" { loadApp, sharedMailboxSeed }
    tests.helpers.fixtures --> "tests/dav-xml.test" { loadFixture }
    "tests/helpers/real-db" --> "tests/draft-visibility-routes.test" { loadApp, sharedMailboxSeed }
    "tests/helpers/real-db" --> "tests/draft-visibility-trash.test" { loadApp, sharedMailboxSeed }
    "tests/helpers/real-db" --> "tests/draft-visibility-writes.test" { loadApp, sharedMailboxSeed }
    "tests/helpers/real-db" --> "tests/draft-visibility.test" { loadApp, sharedMailboxSeed }
    src.lib.drive.utils --> "tests/drive-content-disposition.test" {
        driveContentDisposition,
        normalizeDriveName,
    }
    "src/lib/drive/types.d" --> src.lib.drive.utils { DriveCrumb, DriveRole, DriveRow }
    "deploy/cloudflare-email-relay/src/index" --> "tests/email-relay.test" { default }
    "tests/helpers/real-db" --> "tests/forward-rule-reauth.test" { loadApp }
    "tests/helpers/real-db" --> "tests/forwarding-reauth.test" { loadApp }
    "src/lib/import/gmail-takeout-utils" --> "tests/gmail-takeout-import.test" {
        mapGmailLabels,
        parseGmailLabels,
        runTakeoutImport,
        splitMbox,
    }
    "src/lib/import/zip-utils" --> "tests/gmail-takeout-import.test" {
        listZipEntries,
        openZipEntry,
        readStreamChunks,
    }
    "src/lib/import/gmail-takeout-types.d" --> "src/lib/import/gmail-takeout-utils" {
        TakeoutBatchMessage,
        TakeoutDestination,
        TakeoutImportOptions,
        TakeoutImportSummary,
        TakeoutLabelOptions,
        TakeoutPlacement,
        TakeoutSection,
        TakeoutUploadResponse,
    }
    "src/lib/import/zip-types.d" --> "src/lib/import/zip-utils" { ZipEntry }
    "src/lib/import/gmail-takeout-utils" --> "tests/gmail-takeout-label-encoded-words.test" {
        parseGmailLabels,
    }
    "tests/helpers/dom-component" --> "tests/hotkey-shared-sequence.test" { loadComponent }
    src.lib.email.unsubscribe --> "tests/html-scan-bounds.test" { extractUnsubscribeLinkFromBody }
    src.lib.spam.analyzers.urls --> "tests/html-scan-bounds.test" { analyzeUrls }
    src.lib.email.parse --> src.lib.spam.analyzers.urls { ParsedEmail }
    "src/lib/spam/types.d" --> src.lib.spam.analyzers.urls { PreparedSpamContent, SpamSignal }
    "src/lib/import/imap-utils" --> "tests/imap-chunk-size.test" {
        getImapChunkSize,
        growImapChunkSize,
        isImapConnectionError,
        isMissingImapFolderError,
        isPermanentImapError,
        keepsImapChunkSize,
        planImapFetchGroups,
    }
    "src/lib/import/message-hints-utils" --> "tests/import-message-hints.test" {
        applyImportHints,
        getImportMessageHints,
    }
    "src/lib/import/gmail-takeout-utils" --> "src/lib/import/message-hints-utils" {
        mapGmailLabels,
        parseGmailLabels,
    }
    "src/lib/import/destination-types.d" --> "src/lib/import/message-hints-utils" {
        ImportDestination,
    }
    "tests/helpers/real-db" --> "tests/import-reauthorization.test" { loadApp, sharedMailboxSeed }
    "tests/helpers/real-db" --> "tests/jmap-folder-scope.test" { loadApp, sharedMailboxSeed }
    "tests/promotions-route-harness" --> "tests/jmap-promotion-keyword.test" { loadRoutes, seed }
    "tests/helpers/real-db" --> "tests/jmap-write-gate.test" { loadApp, sharedMailboxSeed }
    "src/lib/profile/identity-utils" --> "tests/mailbox-identity-scope.test" {
        isPrimaryMailbox,
        resolveMailboxAvatarKey,
        resolveMailboxDisplayName,
        tracksAccountIdentity,
    }
    "tests/helpers/real-db" --> "tests/mcp-cancel-scheduled.test" { loadApp, sharedMailboxSeed }
    "tests/helpers/real-db" --> "tests/mutation-origin.test" { loadApp }
    "tests/helpers/real-db" --> "tests/node-env-vars.test" { loadApp }
    tests.helpers.fixtures --> "tests/node-fetch-adapter.test" { loadFixture }
    "tests/helpers/real-db" --> "tests/node-realtime-origin.test" { loadApp }
    tests.helpers.fixtures --> "tests/password-change-race.test" {
        concurrentPasswordWrite,
        installSqlite,
        loadFixture,
    }
    tests.helpers.fixtures --> "tests/password-enrollment.test" { loadFixture, sqliteProxy }
    tests.helpers.fixtures --> "tests/password-reset-race.test" {
        concurrentPasswordWrite,
        installSqlite,
        loadFixture,
    }
    "tests/helpers/real-db" --> "tests/paymug-logging.test" { loadApp }
    "tests/helpers/real-db" --> "tests/private-draft-backfill.test" { loadApp, sharedMailboxSeed }
    "tests/helpers/real-db" --> "tests/private-draft-folder-move.test" {
        loadApp,
        sharedMailboxSeed,
    }
    "tests/helpers/real-db" --> "tests/private-draft-indexes.test" { loadApp, sharedMailboxSeed }
    "tests/helpers/real-db" --> "tests/private-draft-readers.test" { loadApp, sharedMailboxSeed }
    "tests/helpers/real-db" --> "tests/private-draft-writes.test" { loadApp, sharedMailboxSeed }
    "tests/promotions-route-harness" --> "tests/promotions-mode-api.test" {
        DELEGATE,
        as,
        call,
        loadRoutes,
        request,
        seed,
    }
    "tests/promotions-route-harness" --> "tests/promotions-move-api.test" {
        DELEGATE,
        as,
        call,
        loadRoutes,
        request,
        seed,
    }
    "tests/promotions-route-harness" --> "tests/promotions-navigation.test" {
        as,
        call,
        loadRoutes,
        request,
        seed,
    }
    "tests/promotions-route-harness" --> "tests/promotions-subscriptions-api.test" {
        DELEGATE,
        OWNER,
        as,
        call,
        loadRoutes,
        request,
        seed,
    }
    src.lib.push.relay --> "tests/push-relay.test" { isRelayHandle, relayBaseUrl, sendViaRelay }
    "tests/helpers/real-db" --> "tests/recovery-email-reauth.test" { loadApp }
    "deploy/cloudflare-email-relay/src/index" --> "tests/relay-multiple-forwards.test" { default }
    "tests/helpers/real-db" --> "tests/shared-mailbox-contacts.test" { loadApp, sharedMailboxSeed }
    "src/components/compose/sheet-viewport-utils" --> "tests/sheet-viewport.test" {
        getSheetViewportStyle,
    }
    tests.helpers.fixtures --> "tests/step-up-grant-race.test" { installSqlite, loadFixture }
    "tests/helpers/real-db" --> "tests/totp-replay.test" { loadApp }
    src.lib.email.unsubscribe --> "tests/unsubscribe.test" {
        dkimCoveredHeaders,
        extractUnsubscribeLinkFromBody,
        extractUnsubscribeUrlFromRaw,
        parseMailtoUnsubscribe,
    }
    "tests/helpers/real-db" --> "tests/webhook-reauth.test" { loadApp }
    "src/lib/import/zip-utils" --> "tests/zip-utils-limits.test" {
        MAX_ZIP_DIRECTORY_BYTES,
        MAX_ZIP_ENTRIES,
        crc32,
        createZipPartReader,
        listZipEntries,
        readZipEntryBytes,
    }
    "lint.config" --> "vite.config" { default }
    src.db.index --> "scripts/db-smoke" { createDb }
    src.db.schema.index --> "scripts/db-smoke" {
        appSettings,
        calendarEvents,
        contactDetails,
        contacts,
        davCards,
        davCollections,
        domainDeliverability,
        domains,
        emailSuppressions,
        folders,
        jmapChanges,
        mailboxPromotionSettings,
        mailboxes,
        messages,
        spamReputation,
        spamTokenStats,
        users,
        webhooks,
    }
    "src/db/with-database" --> "scripts/db-smoke" { getDatabaseConfig }
    src.db.external --> "scripts/db-smoke" { openExternalDatabase }
    src.lib.migrations.service --> "scripts/db-smoke" { applyPendingMigrations, getMigrationStatus }
    src.lib.search.conditions --> "scripts/db-smoke" { buildSearchConditions }
    src.lib.booking.create --> "scripts/db-smoke" { createBookedCalendarEvents }
    "src/lib/calendar/import-store" --> "scripts/db-smoke" { importCalendarGroups }
    "src/lib/contacts/import-store" --> "scripts/db-smoke" { importContacts }
    src.lib.backups.export --> "scripts/db-smoke" { exportDatabaseRecords, restoreDatabaseRecords }
    "src/lib/search/index-admin" --> "scripts/db-smoke" { getSearchIndexStatus }
    src.lib.spam.repository --> "scripts/db-smoke" { recordReputationObservation }
    "src/lib/database-errors" --> "scripts/db-smoke" { isUniqueConstraintError }
    src.lib.promotions.subscriptions --> "scripts/db-smoke" { listSubscriptions }
    src.lib.promotions.backfill --> "scripts/db-smoke" {
        runPromotionsBackfill,
        selectBackfillCandidates,
    }
    src.lib.deliverability.suppression --> "scripts/db-smoke" { recordSuppression }
    src.lib.deliverability.ingest --> "scripts/db-smoke" { ingestReportMail }
    src.lib.deliverability.daily --> "scripts/db-smoke" { runDeliverabilityDaily }
    "src/lib/deliverability/dmarc-stats" --> "scripts/db-smoke" { getDmarcStats }
    "src/lib/deliverability/tls-stats" --> "scripts/db-smoke" { getTlsStats }
    "src/lib/deliverability/mta-sts-admin" --> "scripts/db-smoke" {
        MtaStsDeps,
        markMtaStsVerified,
        updateMtaSts,
    }
    "src/lib/deliverability/mta-sts-guard" --> "scripts/db-smoke" {
        assertDomainRemovable,
        assertMxChangeAllowed,
    }
    "src/lib/deliverability/mta-sts-serve" --> "scripts/db-smoke" { serveMtaStsPolicy }
    src.db.external --> src.lib.migrations.service { isExternalDatabase }
    src.db.dialect --> src.lib.migrations.service { DatabaseDialect }
    "src/lib/migrations/types.d" --> src.lib.migrations.service {
        BundledMigration,
        MigrationNameRow,
        MigrationResult,
        MigrationStatus,
    }
    src.db.schema.index --> src.lib.search.conditions { messageAttachments, messages }
    src.db.dialect --> src.lib.search.conditions { schemaDialect }
    "src/lib/search/query-utils" --> src.lib.search.conditions {
        buildFtsMatch,
        parseSearchQuery,
        tokenizeSearchText,
    }
    "src/lib/search/types.d" --> src.lib.search.conditions { ParsedSearchQuery }
    "src/lib/search/types.d" --> "src/lib/search/query-utils" { ParsedSearchQuery, SearchToken }
    src.lib.time.utils --> "src/lib/search/query-utils" { dateFromZonedFields, normalizeTimeZone }
    src.db.index --> src.lib.booking.create { getDb }
    src.db.schema.index --> src.lib.booking.create { calendarEvents }
    src.lib.ids --> src.lib.booking.create { newId }
    "src/lib/booking/types.d" --> src.lib.booking.create { BookingEventRecord }
    src.db.index --> "src/lib/calendar/import-store" { AppDatabase }
    src.db.schema.index --> "src/lib/calendar/import-store" { calendarEvents, domains, mailboxes }
    src.lib.http.errors --> "src/lib/calendar/import-store" { RequestBodyTooLargeError }
    "src/lib/calendar/ics-import" --> "src/lib/calendar/import-store" { parseIcsEventGroup }
    "src/lib/calendar/import-store-types.d" --> "src/lib/calendar/import-store" {
        CalendarImportSummary,
        PlannedGroup,
    }
    "src/lib/calendar/import-store-utils" --> "src/lib/calendar/import-store" {
        MAX_REQUEST_EVENTS,
        ROWS_PER_INSERT,
        SELECT_CHUNK,
        STATEMENTS_PER_BATCH,
        candidateIds,
        chunk,
        planCalendarImportRows,
        planGroupIds,
    }
    src.lib.calendar.ics --> "src/lib/calendar/import-store-utils" { isIcsAddress }
    "src/lib/calendar/ics-import-types.d" --> "src/lib/calendar/import-store-utils" {
        ImportEvent,
        ImportGroup,
    }
    "src/lib/calendar/import-store-types.d" --> "src/lib/calendar/import-store-utils" {
        CalendarImportPlan,
        CalendarImportRow,
        ImportGroupIds,
        PlannedGroup,
    }
    "src/lib/calendar/invite-store" --> "src/lib/calendar/import-store-utils" { inviteEventId }
    src.db.index --> "src/lib/calendar/invite-store" { getDb }
    src.db.schema.index --> "src/lib/calendar/invite-store" {
        calendarEventOverrides,
        calendarEvents,
        calendarInviteTombstones,
        calendarOccurrenceResponses,
        users,
    }
    src.lib.ids --> "src/lib/calendar/invite-store" { newId }
    "src/lib/email/attachment-types.d" --> "src/lib/calendar/invite-store" { AttachmentContent }
    src.lib.calendar.invite --> "src/lib/calendar/invite-store" {
        ParsedInvite,
        inviteAttendeeAddresses,
        inviteRepeat,
        parseInvite,
    }
    src.lib.calendar.ics --> "src/lib/calendar/invite-store" { isIcsAddress }
    src.lib.email.address --> "src/lib/calendar/invite-store" { getEmailAddress }
    "src/lib/calendar/invite-attachment" --> "src/lib/calendar/invite-store" {
        MAX_INVITE_BYTES,
        findInviteAttachment,
    }
    "src/lib/calendar/invite-rules" --> "src/lib/calendar/invite-store" {
        addExcludedOccurrence,
        chooseRecipientZone,
        inboundNeedsRecipientZone,
        inviteSenderMatches,
        mergeExcludedOccurrences,
        normalizeInviteSender,
        planInboundInvite,
    }
    src.lib.email.address --> "src/lib/calendar/invite-rules" { getEmailAddress }
    src.lib.time.utils --> "src/lib/calendar/invite-rules" { isValidTimeZone, normalizeTimeZone }
    src.lib.calendar.recurrence --> "src/lib/calendar/invite-rules" { parseExcludedOccurrences }
    src.lib.calendar.invite --> "src/lib/calendar/invite-rules" { ParsedInvite }
    src.db.index --> "src/lib/contacts/import-store" { AppDatabase }
    src.db.schema.index --> "src/lib/contacts/import-store" { contactDetails, contacts }
    "src/lib/database-errors" --> "src/lib/contacts/import-store" { isMissingTableError }
    src.lib.profile.sync --> "src/lib/contacts/import-store" { getPersonalAddresses }
    "src/lib/contacts/details-utils" --> "src/lib/contacts/import-store" { importedContactEmails }
    "src/lib/contacts/import-store-types.d" --> "src/lib/contacts/import-store" {
        ContactImportBody,
        ContactImportSummary,
        ExistingContact,
    }
    "src/lib/contacts/import-store-utils" --> "src/lib/contacts/import-store" {
        CONTACTS_PER_INSERT,
        DETAILS_PER_INSERT,
        SELECT_CHUNK,
        STATEMENTS_PER_BATCH,
        chunk,
        parseContactImportCards,
        planContactImport,
    }
    src.lib.contacts.utils --> "src/lib/contacts/import-store" { getContactId }
    src.db.index --> src.lib.profile.sync { AppDatabase }
    src.db.schema.index --> src.lib.profile.sync { contacts, domains, mailboxes, users }
    src.lib.contacts.utils --> src.lib.profile.sync { getContactId }
    "src/lib/mailboxes/domain-addresses" --> src.lib.profile.sync { getMailboxDomainAddresses }
    "src/lib/profile/identity-utils" --> src.lib.profile.sync { tracksAccountIdentity }
    "src/lib/profile/sync-types.d" --> src.lib.profile.sync { PersonalIdentity }
    "src/lib/contacts/types.d" --> "src/lib/contacts/details-utils" { ContactNameSource }
    "src/lib/contacts/details-types.d" --> "src/lib/contacts/details-utils" { ContactDetailsData }
    src.lib.http.errors --> "src/lib/contacts/import-store-utils" { RequestBodyTooLargeError }
    "src/lib/contacts/details-utils" --> "src/lib/contacts/import-store-utils" {
        importedContactEmails,
        mergeContactDetails,
        mergeImportedContact,
        normalizeContactDetails,
        parseStoredDetails,
    }
    "src/lib/contacts/google-csv" --> "src/lib/contacts/import-store-utils" {
        MAX_CSV_COLUMNS,
        MAX_CSV_FIELD,
        googleCsvMapper,
    }
    "src/lib/contacts/import-store-types.d" --> "src/lib/contacts/import-store-utils" {
        ContactImportBody,
        ContactImportPlan,
        ExistingContact,
        ImportedCard,
    }
    src.lib.contacts.utils --> "src/lib/contacts/import-store-utils" { getContactId }
    src.lib.contacts.vcard --> "src/lib/contacts/import-store-utils" { MAX_CARD_CHARS, parseVcard }
    "src/lib/contacts/details-utils" --> "src/lib/contacts/google-csv" {
        cleanLine,
        cleanText,
        normalizeContactDetails,
        withoutEmails,
    }
    "src/lib/contacts/vcard-types.d" --> "src/lib/contacts/google-csv" { ImportedContact }
    "src/lib/calendar/ics-import" --> src.lib.contacts.vcard { iterIcsLines }
    "src/lib/contacts/details-utils" --> src.lib.contacts.vcard {
        cleanLine,
        cleanText,
        normalizeContactDetails,
        withoutEmails,
    }
    "src/lib/contacts/vcard-types.d" --> src.lib.contacts.vcard {
        ContactPhoto,
        ImportedContact,
        SplitVcard,
        SplitVcardsResult,
    }
    src.db.introspect --> src.lib.backups.export {
        dialectOf,
        listColumnNames,
        listTableNames,
        quoteIdentifier,
    }
    src.db.dialect --> src.lib.backups.export { DatabaseDialect }
    "src/lib/backups/types.d" --> src.lib.backups.export {
        BackupTableGroupId,
        DatabaseBackupDocument,
        DatabaseBackupTable,
        DatabaseRecord,
    }
    src.lib.backups.utils --> src.lib.backups.export { mergeLegacyMessageBodies }
    "src/lib/backups/table-groups" --> src.lib.backups.export {
        BACKUP_TABLE_GROUPS,
        getSelectedBackupTables,
    }
    src.db.dialect --> src.db.introspect { DatabaseDialect }
    src.db.external --> src.db.introspect { isExternalDatabase }
    "src/lib/backups/types.d" --> src.lib.backups.utils {
        BackupScheduleType,
        DatabaseBackupDocument,
        DatabaseRecord,
    }
    "src/lib/backups/types.d" --> "src/lib/backups/table-groups" {
        BackupTableGroupId,
        DatabaseBackupTable,
    }
    src.db.introspect --> "src/lib/search/index-admin" { dialectOf }
    src.db.index --> src.lib.spam.repository { getDb }
    src.db.schema.index --> src.lib.spam.repository { spamReputation }
    "src/lib/spam/types.d" --> src.lib.spam.repository { ReputationKey }
    src.db.index --> src.lib.promotions.subscriptions { getDb }
    src.db.schema.index --> src.lib.promotions.subscriptions { mailboxSenderPreferences, messages }
    src.lib.ids --> src.lib.promotions.subscriptions { newId }
    "src/lib/database-errors" --> src.lib.promotions.subscriptions { isMissingTableError }
    src.lib.email.address --> src.lib.promotions.subscriptions { getEmailDisplayName }
    "src/lib/email/sender-sweep" --> src.lib.promotions.subscriptions { senderSweepCondition }
    "src/lib/promotions/subscriptions-utils" --> src.lib.promotions.subscriptions {
        MAX_SWEEP_ROWS,
        SUBSCRIPTIONS_PAGE_SIZE,
        SUBSCRIPTION_WINDOW_DAYS,
        SWEEP_CHUNK_SIZE,
        SWEEP_WINDOW_DAYS,
        chunk,
        isStillSending,
        windowStart,
    }
    src.db.schema.index --> "src/lib/email/sender-sweep" { messages }
    src.db.sql --> "src/lib/email/sender-sweep" { escapeLike, insensitiveLike }
    "src/lib/promotions/refile-utils" --> "src/lib/promotions/subscriptions-utils" { chunk }
    "src/lib/promotions/classify-utils" --> "src/lib/promotions/subscriptions-utils" {
        toSenderAddress,
    }
    "src/lib/promotions/classify-utils" --> "src/lib/promotions/refile-utils" { toSenderAddress }
    src.lib.email.address --> "src/lib/promotions/classify-utils" { normalizeEmailAddress }
    "src/lib/email/bulk-mail" --> "src/lib/promotions/classify-utils" { BulkMailVerdict }
    src.db.index --> src.lib.promotions.backfill { getDb }
    src.db.schema.index --> src.lib.promotions.backfill {
        contacts,
        mailboxPromotionSettings,
        mailboxSenderPreferences,
        messages,
    }
    "src/lib/database-errors" --> src.lib.promotions.backfill {
        isMissingColumnError,
        isMissingTableError,
    }
    "src/lib/email/bulk-mail" --> src.lib.promotions.backfill { detectBulkMail }
    "src/lib/email/provider-trace" --> src.lib.promotions.backfill { readHeaderMap }
    "src/lib/promotions/classify-utils" --> src.lib.promotions.backfill {
        decideCategory,
        toSenderAddress,
    }
    "src/lib/promotions/backfill-utils" --> src.lib.promotions.backfill {
        BACKFILL_BATCH,
        BACKFILL_CHUNK,
        BACKFILL_DAILY_CAP,
        BACKFILL_HEAD_BYTES,
        BACKFILL_MAX_STALLS,
        BACKFILL_STALE_MS,
        BACKFILL_WINDOW_DAYS,
        BackfillCursor,
        backfillCutoff,
        backfillDay,
        parseCursor,
        serializeCursor,
    }
    "src/lib/promotions/refile-utils" --> src.lib.promotions.backfill { chunk }
    "src/lib/spam/types.d" --> "src/lib/email/provider-trace" { ProviderVerdicts }
    "src/lib/email/authentication-types.d" --> "src/lib/email/provider-trace" {
        MessageAuthentication,
        MessageAuthenticationMethod,
    }
    "src/lib/email/domain-match" --> "src/lib/email/provider-trace" { isSameOrSubdomain }
    "src/lib/spam/domain-utils" --> "src/lib/email/provider-trace" { extractSenderIp }
    src.db.index --> src.lib.deliverability.ingest { getDb }
    src.db.schema.index --> src.lib.deliverability.ingest {
        deliverabilityReports,
        dmarcDailyStats,
        domainDeliverability,
        tlsDailyStats,
    }
    "src/lib/database-errors" --> src.lib.deliverability.ingest {
        isMissingColumnError,
        isUniqueConstraintError,
    }
    "src/lib/dns-query" --> src.lib.deliverability.ingest { queryDns, reverseName }
    src.lib.email.parse --> src.lib.deliverability.ingest { parseRawMime }
    "src/lib/deliverability/org-domain" --> src.lib.deliverability.ingest { addressOrganisation }
    "src/lib/deliverability/report-parse" --> src.lib.deliverability.ingest {
        DmarcReport,
        REPORT_LIMITS,
        ReportError,
        TlsReport,
        extractReportXml,
        parseDmarcAggregateXml,
        parseTlsRptJson,
        rawReportKey,
        reportKey,
        rowKey,
        tlsRowKey,
    }
    src.lib.email.address --> "src/lib/deliverability/org-domain" { getEmailAddressList }
    "src/lib/dns-query" --> "src/lib/deliverability/report-parse" { reverseName }
    "src/lib/import/zip-utils" --> "src/lib/deliverability/report-parse" {
        listZipEntries,
        openZipEntry,
        sliceChunks,
    }
    src.db.index --> src.lib.deliverability.daily { getDb }
    src.db.schema.index --> src.lib.deliverability.daily {
        deliverabilityAlerts,
        deliverabilityReports,
        dmarcDailyStats,
        domainDeliverability,
        domains,
        tlsDailyStats,
        users,
    }
    "src/lib/database-errors" --> src.lib.deliverability.daily {
        isMissingColumnError,
        isMissingTableError,
    }
    "src/lib/email/system-mail-types.d" --> src.lib.deliverability.daily { SystemMailInput }
    "src/lib/deliverability/mta-sts-admin" --> src.lib.deliverability.daily {
        MtaStsDeps,
        retireMtaSts,
    }
    "src/lib/deliverability/daily-utils" --> src.lib.deliverability.daily {
        AlertKind,
        EvaluatedAlert,
        SourceTotals,
        evaluateNoReports,
        evaluateSourceAlerts,
        mergeReporterAlerts,
    }
    "src/lib/email/system-mail" --> src.lib.deliverability.daily;
    src.db.index --> "src/lib/deliverability/mta-sts-admin" { getDb }
    src.db.schema.index --> "src/lib/deliverability/mta-sts-admin" { domainDeliverability, domains }
    "src/lib/cloudflare-dns" --> "src/lib/deliverability/mta-sts-admin" { listMxRecords }
    "src/lib/dns-query" --> "src/lib/deliverability/mta-sts-admin" { queryDns }
    "src/lib/deliverability/mta-sts" --> "src/lib/deliverability/mta-sts-admin" {
        MTA_STS_LIMITS,
        MtaStsMode,
        buildMtaStsPolicy,
        nextPolicyId,
        normalizeMx,
        parseMaxAge,
    }
    "src/lib/deliverability/reports-admin" --> "src/lib/deliverability/mta-sts-admin" {
        DnsReadError,
        MultipleRecordsError,
        ReportsDeps,
        isManual,
        isZoneUnavailable,
        readTxtRecord,
        reportsDeps,
        unquote,
    }
    "src/lib/cloudflare-api" --> "src/lib/cloudflare-dns" { cfRequest }
    "src/lib/cloudflare-api.types.d" --> "src/lib/cloudflare-dns" { CfDnsRecord }
    "src/lib/cloudflare-dns.types.d" --> "src/lib/cloudflare-dns" { CloudflareDnsRecordCreate }
    src.db.index --> "src/lib/deliverability/reports-admin" { getDb }
    src.db.schema.index --> "src/lib/deliverability/reports-admin" {
        domainDeliverability,
        mailboxAliases,
        mailboxes,
    }
    "src/lib/cloudflare-api" --> "src/lib/deliverability/reports-admin" {
        deleteEmailRoutingRuleForAddress,
        ensureEmailRoutingRuleToWorker,
    }
    "src/lib/cloudflare-dns" --> "src/lib/deliverability/reports-admin" {
        createDnsRecord,
        deleteDnsRecord,
        listDnsRecords,
        updateDnsRecord,
    }
    "src/lib/cloudflare-api-error" --> "src/lib/deliverability/reports-admin" {
        isCloudflareZoneUnavailable,
    }
    "src/lib/dns-query" --> "src/lib/deliverability/reports-admin" { queryDns }
    "src/lib/deliverability/dmarc-record" --> "src/lib/deliverability/reports-admin" {
        withRuaUri,
        withoutRuaUri,
    }
    "src/lib/deliverability/org-domain" --> "src/lib/deliverability/reports-admin" {
        organisationalDomain,
    }
    "src/lib/deliverability/report-address" --> "src/lib/deliverability/reports-admin" {
        REPORT_ADDRESS_LOCAL_PART,
        reportAddress,
    }
    src.db.index --> "src/lib/deliverability/report-address" { getDb }
    src.db.schema.index --> "src/lib/deliverability/report-address" {
        domainDeliverability,
        domains,
    }
    "src/lib/database-errors" --> "src/lib/deliverability/report-address" { isMissingTableError }
    src.db.index --> "src/lib/email/system-mail" { getDb }
    src.db.schema.index --> "src/lib/email/system-mail" { domains, mailboxes, users }
    src.lib.email.address --> "src/lib/email/system-mail" { formatEmailAddress }
    "src/lib/email/outbound-provider" --> "src/lib/email/system-mail" {
        getOutboundProviderConfig,
        sendThroughProvider,
    }
    "src/lib/email/system-mail-types.d" --> "src/lib/email/system-mail" { SystemMailInput }
    src.db.index --> "src/lib/deliverability/dmarc-stats" { getDb }
    src.db.schema.index --> "src/lib/deliverability/dmarc-stats" {
        deliverabilityReports,
        dmarcDailyStats,
    }
    src.db.index --> "src/lib/deliverability/tls-stats" { getDb }
    src.db.schema.index --> "src/lib/deliverability/tls-stats" {
        deliverabilityReports,
        tlsDailyStats,
    }
    "src/lib/deliverability/dmarc-stats" --> "src/lib/deliverability/tls-stats" {
        DmarcDays,
        DmarcRecentReport,
    }
    src.db.index --> "src/lib/deliverability/mta-sts-guard" { getDb }
    src.db.schema.index --> "src/lib/deliverability/mta-sts-guard" { domainDeliverability, domains }
    "src/lib/database-errors" --> "src/lib/deliverability/mta-sts-guard" {
        isMissingColumnError,
        isMissingTableError,
    }
    "src/lib/deliverability/mta-sts-admin" --> "src/lib/deliverability/mta-sts-guard" {
        MtaStsDeps,
        deleteMtaStsRecord,
        mtaStsDeps,
        updateMtaSts,
    }
    "src/lib/deliverability/reports-admin" --> "src/lib/deliverability/mta-sts-guard" {
        ReportsDeps,
        isManual,
        reportsDeps,
    }
    "src/lib/deliverability/tls-rpt-admin" --> "src/lib/deliverability/mta-sts-guard" {
        updateTlsRpt,
    }
    src.db.index --> "src/lib/deliverability/tls-rpt-admin" { getDb }
    src.db.schema.index --> "src/lib/deliverability/tls-rpt-admin" { domainDeliverability }
    "src/lib/deliverability/dmarc-record" --> "src/lib/deliverability/tls-rpt-admin" {
        hasTlsRuaUri,
        withTlsRuaUri,
        withoutTlsRuaUri,
    }
    "src/lib/deliverability/reports-admin" --> "src/lib/deliverability/tls-rpt-admin" {
        DnsReadError,
        MultipleRecordsError,
        ReportsDeps,
        isManual,
        isZoneUnavailable,
        readTxtRecord,
        reportsDeps,
    }
    "src/lib/deliverability/report-address" --> "src/lib/deliverability/tls-rpt-admin" {
        reportAddress,
    }
    src.db.index --> "src/lib/deliverability/mta-sts-serve" { getDb }
    src.db.schema.index --> "src/lib/deliverability/mta-sts-serve" { domainDeliverability, domains }
    "src/lib/database-errors" --> "src/lib/deliverability/mta-sts-serve" {
        isMissingColumnError,
        isMissingTableError,
    }
    "src/lib/deliverability/mta-sts" --> "src/lib/deliverability/mta-sts-serve" {
        buildMtaStsPolicy,
        hostnameOf,
        mtaStsHostDomain,
        normalizeMx,
        parseMaxAge,
    }
    "src/lib/import/gmail-takeout-utils" --> "scripts/import-gmail-takeout" {
        runTakeoutImport,
        splitMbox,
    }
    src.db.index --> "scripts/passkey-recovery-link" { createDb }
    src.db.external --> "scripts/passkey-recovery-link" { openExternalDatabase }
    src.db.schema.index --> "scripts/passkey-recovery-link" { users }
    "src/db/with-database" --> "scripts/passkey-recovery-link" { getDatabaseConfig }
    src.lib.auth.webauthn.grants --> "scripts/passkey-recovery-link" { createEnrollmentGrant }
    src.lib.auth.session --> "scripts/passkey-recovery-link" { hashSessionToken }
    src.lib.ids --> "scripts/passkey-recovery-link" { newId }
    src.db.index --> src.lib.auth.webauthn.grants { getDb }
    src.db.schema.index --> src.lib.auth.webauthn.grants {
        authStepUps,
        passkeyEnrollmentGrants,
        users,
    }
    src.lib.ids --> src.lib.auth.webauthn.grants { newId }
    src.lib.auth.session --> src.lib.auth.webauthn.grants { hashSessionToken }
    "src/lib/auth/webauthn/step-up-types.d" --> src.lib.auth.webauthn.grants { StepUpAction }
    src.lib.auth.session --> server.index { getUserFromSession }
    src.lib.realtime.utils --> server.index { getSessionTokenFromRequest }
    src.lib.email.inbound --> server.index { processInboundMessage }
    src.lib.agent.jobs.utils --> server.index { processAgentDraftJob }
    src.lib.email.send --> server.index { OutboundQueueMessage, processOutboundQueue }
    src.lib.email.webhooks --> server.index { WebhookRetryMessage, processWebhookRetry }
    src.lib.import.jobs --> server.index { processImportJob }
    src.lib.dav.handler --> server.index { handleDavRequest, isDavPath }
    "src/lib/deliverability/mta-sts" --> server.index { guardMtaStsHost, hostnameOf, isMtaStsHost }
    src.lib.migrations.service --> server.index { applyPendingMigrations }
    "worker-utils" --> server.index {
        isImportJobMessage,
        isInboundQueueMessage,
        isWebhookRetryMessage,
    }
    server.runtime.env --> server.index { createNodeRuntime }
    "server/runtime/realtime-origin" --> server.index { isRealtimeOriginAllowed }
    "server/runtime/fetch-adapter" --> server.index { serveFetch }
    server.runtime.migrate --> server.index { applyMigrations }
    server.runtime.scheduler --> server.index { startScheduler }
    server.runtime.smtp --> server.index { startSmtpListener }
    src.db.index --> src.lib.realtime.utils { getDb }
    src.db.schema.index --> src.lib.realtime.utils { domains, mailboxAccess, mailboxes }
    "src/lib/mailboxes/access-utils" --> src.lib.realtime.utils { isTeamMailboxSharingEnabled }
    src.lib.realtime.revision --> src.lib.realtime.utils { getUserMailRevision }
    "src/lib/realtime/types.d" --> src.lib.realtime.utils {
        AgentDraftNotification,
        NewMessageNotification,
        RevisionNotification,
    }
    src.lib.push.server --> src.lib.realtime.utils { sendPushNotifications }
    src.lib.push.native --> src.lib.realtime.utils { sendNativePush }
    src.db.index --> src.lib.push.server { getDb }
    src.db.schema.index --> src.lib.push.server { pushSubscriptions, sessions }
    "src/lib/realtime/types.d" --> src.lib.push.server { NewMessageNotification }
    "src/lib/email/sender-label" --> src.lib.push.server { formatSenderLabel }
    src.lib.email.address ++> "src/lib/email/sender-label" { getEmailAddress }
    src.db.index --> src.lib.push.native { getDb }
    src.db.schema.index --> src.lib.push.native { pushDevices }
    src.lib.ids --> src.lib.push.native { newId }
    "src/lib/realtime/types.d" --> src.lib.push.native { NewMessageNotification }
    "src/lib/push/native-crypto" --> src.lib.push.native {
        encryptPreview,
        importApnsKey,
        signApnsJwt,
    }
    src.lib.push.relay --> src.lib.push.native { isRelayHandle, relayBaseUrl, sendViaRelay }
    src.db.index --> src.lib.email.inbound { getDb }
    src.db.schema.index --> src.lib.email.inbound { messages, outboundJobs, users }
    src.lib.ids --> src.lib.email.inbound { newId }
    src.lib.email.parse --> src.lib.email.inbound { buildSnippet, parseRawMime }
    "src/lib/deliverability/report-address" --> src.lib.email.inbound { matchReportAddress }
    src.lib.deliverability.ingest --> src.lib.email.inbound { BatchBudget, ingestReportMail }
    src.lib.spam.analyzers.authentication --> src.lib.email.inbound { readTrustedDmarcResult }
    "src/lib/email/inbound-limits" --> src.lib.email.inbound { boundParsedEmail }
    src.lib.email.routing --> src.lib.email.inbound {
        resolveInboundAddress,
        resolveInboxRuleDestination,
    }
    src.lib.email.webhooks --> src.lib.email.inbound { dispatchWebhooks }
    src.lib.contacts.service --> src.lib.email.inbound {
        getMessageContactNames,
        upsertContactFromAddress,
    }
    src.lib.email.address --> src.lib.email.inbound { getEmailAddress }
    "src/lib/email/auto-reply" --> src.lib.email.inbound { sendMailboxAutoReply }
    "src/lib/email/draft-access" --> src.lib.email.inbound { isOthersDraft }
    src.lib.deliverability.suppression --> src.lib.email.inbound { recordDsnBounces }
    src.lib.mailboxes.access --> src.lib.email.inbound { getMailboxAccessLevel }
    src.lib.email.attachments --> src.lib.email.inbound {
        listMessageAttachments,
        storeMessageAttachments,
    }
    "src/lib/calendar/invite-store" --> src.lib.email.inbound { registerInboundInvite }
    "src/lib/email/inbound-attachments" --> src.lib.email.inbound { inboundAttachmentLimitReason }
    "src/lib/email/inbound-id" --> src.lib.email.inbound { inboundMessageId }
    src.lib.email.unsubscribe --> src.lib.email.inbound {
        extractUnsubscribeLinkFromBody,
        extractUnsubscribeUrlFromRaw,
        getUnsubscribeUrlFromRawR2Key,
    }
    src.lib.email.threading --> src.lib.email.inbound { resolveThreadId }
    "src/lib/email/thread-lookup" --> src.lib.email.inbound { normalizeMessageId }
    "src/lib/auth/types.d" --> src.lib.email.inbound { SessionUser }
    src.lib.spam.engine --> src.lib.email.inbound { analyzeSpam }
    src.lib.spam.providers.external --> src.lib.email.inbound { ExternalSpamIntelligenceProvider }
    src.lib.spam.settings --> src.lib.email.inbound { getSpamIntelligenceConfig }
    "src/lib/spam/types.d" --> src.lib.email.inbound { ProviderVerdicts }
    src.lib.spam.analyzers.reputation --> src.lib.email.inbound { getReputationKeys }
    src.lib.spam.repository --> src.lib.email.inbound { recordReputationObservation }
    src.lib.realtime.utils --> src.lib.email.inbound {
        getMailboxNotificationUserIds,
        notifyUsersOfNewMessage,
    }
    src.lib.agent.jobs.utils --> src.lib.email.inbound { scheduleAutoDraft }
    "src/lib/promotions/mode-utils" --> src.lib.email.inbound { isSilentPromotion }
    src.lib.promotions.settings --> src.lib.email.inbound { PromotionMode, loadPromotionModes }
    "src/lib/email/inbound-notification" --> src.lib.email.inbound { buildNewMessageNotification }
    "src/lib/email/provider-trace" --> src.lib.email.inbound { readHeaderMap }
    src.lib.promotions.classify --> src.lib.email.inbound { classifyInboundCategory }
    "src/lib/spam/types.d" --> src.lib.spam.analyzers.authentication {
        ProviderVerdicts,
        SpamSignal,
    }
    src.lib.spam.weights --> src.lib.spam.analyzers.authentication { SPAM_WEIGHTS }
    src.lib.spam.analyzers.utils --> src.lib.spam.analyzers.authentication { findHeader }
    src.db.index --> src.lib.email.routing { AppDatabase }
    src.db.schema.index --> src.lib.email.routing {
        domains,
        folders,
        mailboxAliases,
        mailboxes,
        routingRules,
    }
    src.lib.email.address --> src.lib.email.routing { getEmailAddress }
    "src/lib/mailboxes/domain-addresses" --> src.lib.email.routing { getMailboxDomainAddresses }
    "src/lib/email/bulk-mail" --> src.lib.email.routing { MailHeaders, isBulkMail }
    "src/lib/email/mail-type-rule" --> src.lib.email.routing { MAIL_TYPE_BULK }
    "src/lib/email/recipient-address" --> src.lib.email.routing {
        normalizeRecipientLocalPart,
        parseRecipientAddress,
    }
    src.db.index --> "src/lib/email/auto-reply" { getDb }
    src.db.schema.index --> "src/lib/email/auto-reply" { autoReplyDeliveries, mailboxes }
    src.lib.email.address --> "src/lib/email/auto-reply" {
        formatEmailAddress,
        normalizeEmailAddress,
    }
    src.lib.email.routing --> "src/lib/email/auto-reply" { resolveInboundAddress }
    src.lib.email.send --> "src/lib/email/auto-reply" { sendEmail }
    "src/lib/deliverability/suppression-utils" --> "src/lib/email/auto-reply" {
        SuppressedRecipientError,
    }
    src.lib.ids --> "src/lib/email/auto-reply" { newId }
    "src/lib/email/auto-reply-types.d" --> "src/lib/email/auto-reply" { MailboxAutoReplyInput }
    "src/lib/email/bulk-mail" --> "src/lib/email/auto-reply" { hasListOrBulkPrecedence }
    src.lib.email.attachments --> "src/lib/email/inbound-attachments" {
        MAX_ATTACHMENT_COUNT,
        MAX_ATTACHMENT_SIZE,
        MAX_TOTAL_ATTACHMENT_SIZE,
    }
    src.lib.email.parse --> "src/lib/email/inbound-attachments" { MimeLimitError, parseRawMime }
    "src/lib/email/attachment-types.d" --> "src/lib/email/inbound-attachments" { AttachmentContent }
    src.db.index --> src.lib.spam.engine { AppDatabase }
    src.db.schema.index --> src.lib.spam.engine { contacts, domains, spamReputation }
    src.db.sql --> src.lib.spam.engine { charIndex }
    src.lib.email.address --> src.lib.spam.engine { getEmailAddress }
    src.lib.spam.analyzers.authentication --> src.lib.spam.engine { analyzeAuthentication }
    src.lib.spam.analyzers.impersonation --> src.lib.spam.engine { analyzeImpersonation }
    "src/lib/spam/domain-utils" --> src.lib.spam.engine { extractSenderIp }
    src.lib.spam.analyzers.reputation --> src.lib.spam.engine { getReputationKeys }
    src.lib.spam.analyzers.utils --> src.lib.spam.engine { findHeader }
    src.lib.spam.analyzers.solicitation --> src.lib.spam.engine { analyzeSolicitation }
    src.lib.spam.analyzers.structure --> src.lib.spam.engine { analyzeStructure }
    src.lib.spam.analyzers.urls --> src.lib.spam.engine { analyzeUrls }
    src.lib.spam.classifier --> src.lib.spam.engine { classifyTokens }
    src.lib.spam.tokenizer --> src.lib.spam.engine {
        buildFingerprint,
        getDomain,
        prepareSpamContent,
        tokenizeMessage,
    }
    "src/lib/spam/types.d" --> src.lib.spam.engine {
        SpamAnalysisInput,
        SpamAnalysisResult,
        SpamSignal,
    }
    src.lib.spam.weights --> src.lib.spam.engine {
        SPAM_STRICTNESS_THRESHOLDS,
        SPAM_THRESHOLDS,
        SPAM_WEIGHTS,
    }
    src.lib.spam.providers.local --> src.lib.spam.engine { LocalSpamIntelligenceProvider }
    src.lib.email.address --> src.lib.spam.analyzers.impersonation {
        getEmailAddress,
        parseEmailAddressParts,
    }
    "src/lib/spam/domain-utils" --> src.lib.spam.analyzers.impersonation {
        domainOwnerLabel,
        isLookalikeDomain,
        registrableDomain,
    }
    "src/lib/spam/types.d" --> src.lib.spam.analyzers.impersonation { SpamBrand, SpamSignal }
    src.lib.spam.weights --> src.lib.spam.analyzers.impersonation { SPAM_WEIGHTS }
    src.lib.email.address --> src.lib.spam.analyzers.reputation { getEmailAddress }
    src.lib.email.parse --> src.lib.spam.analyzers.reputation { ParsedEmail }
    src.lib.spam.tokenizer --> src.lib.spam.analyzers.reputation { getDomain }
    src.lib.email.address --> src.lib.spam.tokenizer { getEmailAddress }
    "src/lib/email/reply-content-utils" --> src.lib.spam.tokenizer { htmlToReadableText }
    src.lib.email.parse --> src.lib.spam.tokenizer { ParsedEmail }
    "src/lib/spam/types.d" --> src.lib.spam.tokenizer { PreparedSpamContent }
    src.lib.spam.weights --> src.lib.spam.tokenizer { MAX_CANDIDATE_TOKENS }
    src.lib.email.address --> src.lib.spam.analyzers.solicitation { getEmailAddress }
    src.lib.email.parse --> src.lib.spam.analyzers.solicitation { ParsedEmail }
    "src/lib/spam/domain-utils" --> src.lib.spam.analyzers.solicitation { registrableDomain }
    "src/lib/spam/types.d" --> src.lib.spam.analyzers.solicitation {
        PreparedSpamContent,
        SpamSignal,
    }
    src.lib.spam.weights --> src.lib.spam.analyzers.solicitation { SPAM_WEIGHTS }
    src.lib.email.parse --> src.lib.spam.analyzers.structure { ParsedEmail }
    "src/lib/spam/types.d" --> src.lib.spam.analyzers.structure { PreparedSpamContent, SpamSignal }
    src.lib.spam.tokenizer --> src.lib.spam.analyzers.structure { getDomain }
    src.lib.spam.analyzers.utils --> src.lib.spam.analyzers.structure { findHeader }
    src.db.index --> src.lib.spam.classifier { AppDatabase }
    src.db.schema.index --> src.lib.spam.classifier { spamFeedback, spamTokenStats }
    "src/lib/spam/types.d" --> src.lib.spam.classifier { BayesianResult }
    src.lib.spam.weights --> src.lib.spam.classifier { MAX_BAYESIAN_TOKENS, SPAM_WEIGHTS }
    "src/lib/spam/types.d" --> src.lib.spam.providers.local { SpamIntelligenceProvider, SpamSignal }
    "src/lib/dns-query" --> src.lib.spam.providers.external { queryDns }
    "src/lib/security/public-url" --> src.lib.spam.providers.external { isPublicHttpsUrl }
    "src/lib/spam/domain-utils" --> src.lib.spam.providers.external { registrableDomain }
    "src/lib/spam/lookup-cache" --> src.lib.spam.providers.external { cachedLookup }
    "src/lib/spam/types.d" --> src.lib.spam.providers.external {
        SpamIntelligenceConfig,
        SpamIntelligenceInput,
        SpamIntelligenceProvider,
        SpamSignal,
    }
    src.lib.spam.weights --> src.lib.spam.providers.external { SPAM_WEIGHTS }
    src.db.index --> src.lib.spam.settings { getDb }
    src.db.schema.index --> src.lib.spam.settings { appSettings }
    "src/lib/dns-query" --> src.lib.spam.settings { queryDns }
    "src/lib/spam/types.d" --> src.lib.spam.settings {
        SpamBrand,
        SpamIntelligenceConfig,
        SpamIntelligenceStatus,
    }
    src.db.index --> src.lib.agent.jobs.utils { getDb }
    src.db.dialect --> src.lib.agent.jobs.utils { schemaDialect }
    src.db.schema.index --> src.lib.agent.jobs.utils {
        agentDraftMetadata,
        agentJobs,
        mailboxAgentSettings,
        mailboxes,
        messages,
        users,
    }
    "src/lib/email/draft-access" --> src.lib.agent.jobs.utils { draftsVisibleTo }
    src.lib.mailboxes.access --> src.lib.agent.jobs.utils { getMailboxAccessLevel }
    src.lib.email.address --> src.lib.agent.jobs.utils { normalizeEmailAddress }
    "src/lib/email/reply-content-utils" --> src.lib.agent.jobs.utils { htmlToReadableText }
    src.lib.ids --> src.lib.agent.jobs.utils { newId }
    src.lib.agent.model --> src.lib.agent.jobs.utils { getAgentModel }
    src.lib.agent.provider --> src.lib.agent.jobs.utils { getAgentEnabled }
    src.lib.ai.usage --> src.lib.agent.jobs.utils { recordAiUsage }
    src.lib.agent.errors --> src.lib.agent.jobs.utils { agentProviderErrorMessage }
    src.lib.agent.tools --> src.lib.agent.jobs.utils { runEmailTool }
    src.lib.realtime.utils --> src.lib.agent.jobs.utils { notifyUsersOfNewMessage }
    "src/lib/mailboxes/domain-addresses" --> src.lib.agent.jobs.utils { getMailboxDomainAddresses }
    src.lib.agent.provider --> src.lib.agent.model { getAgentProviderConfig }
    "src/lib/agent/provider-constants" --> src.lib.agent.model { PROVIDER_BASE_URLS }
    src.lib.agent.time --> src.lib.agent.model { agentTimeContext }
    src.db.index --> src.lib.agent.provider { getDb }
    src.db.schema.index --> src.lib.agent.provider { appSettings }
    "src/lib/agent/provider-types.d" --> src.lib.agent.provider {
        AgentProviderConfig,
        AgentProviderPreset,
        AgentProviderPublicConfig,
    }
    "src/lib/agent/provider-constants" --> src.lib.agent.provider {
        AGENT_SETTINGS_ID,
        DEFAULT_CLOUDFLARE_MODEL,
        PROVIDER_BASE_URLS,
    }
    "src/lib/agent/model-ids" --> src.lib.agent.provider { parseAgentModelIds }
    src.lib.agent.pricing --> src.lib.agent.provider { parseAgentModelRates }
    "src/lib/agent/provider-types.d" --> "src/lib/agent/provider-constants" { AgentProviderPreset }
    "src/lib/agent/provider-types.d" --> src.lib.agent.pricing { AgentModelRates }
    src.db.index --> src.lib.ai.usage { getDb }
    src.db.schema.index --> src.lib.ai.usage { aiUsage }
    src.lib.ids --> src.lib.ai.usage { newId }
    src.lib.agent.pricing --> src.lib.ai.usage { calculateAgentCostUsdMicros }
    "src/lib/ai/usage-types.d" --> src.lib.ai.usage { RecordAiUsageInput }
    "src/lib/email/draft-access" --> src.lib.agent.tools { draftsVisibleTo, isOthersDraft }
    src.lib.email.scheduled --> src.lib.agent.tools { scheduledMessageCondition }
    src.db.index --> src.lib.agent.tools { getDb }
    src.db.schema.index --> src.lib.agent.tools { agentDraftMetadata, domains, mailboxes, messages }
    src.lib.email.parse --> src.lib.agent.tools { buildSnippet }
    src.lib.email.sender --> src.lib.agent.tools { getAuthorizedSenderAddress }
    src.lib.email.threading --> src.lib.agent.tools {
        buildReplyReferences,
        formatMessageIdHeader,
        parseMessageIdList,
    }
    src.lib.mailboxes.access --> src.lib.agent.tools { getMailboxAccessLevel }
    src.lib.search.conditions --> src.lib.agent.tools { buildSearchConditions }
    src.lib.ids --> src.lib.agent.tools { newId }
    "src/lib/email/message-cleanup" --> src.lib.agent.tools { deleteMessageWithObjects }
    src.lib.email.attachments --> src.lib.agent.tools { listMessageAttachments }
    "src/lib/email/reply-content-utils" --> src.lib.agent.tools { htmlToReadableText }
    src.lib.user --> src.lib.agent.tools { updateMessageStatusForUser }
    "src/lib/agent/types.d" --> src.lib.agent.tools {
        AgentDraftEditInput,
        AgentToolContext,
        EmailToolName,
    }
    src.lib.agent.reply --> src.lib.agent.tools { getReplyRecipients }
    "src/lib/agent/draft-format" --> src.lib.agent.tools { formatAgentDraftBody }
    "src/lib/agent/edit-draft" --> src.lib.agent.tools { editAgentDraft }
    src.lib.agent.approvals.utils --> src.lib.agent.tools { requestAgentSend }
    "src/lib/agent/schema-utils" --> src.lib.agent.tools { toolEmailSchema }
    src.db.index --> src.lib.email.scheduled { getDb }
    src.db.schema.index --> src.lib.email.scheduled { messages, outboundJobs }
    "src/lib/email/draft-access" --> src.lib.email.scheduled { logMessageHidden }
    src.db.index --> src.lib.user { getDb }
    src.db.schema.index --> src.lib.user { domains, mailboxes, messages }
    "src/lib/email/draft-access" --> src.lib.user {
        isOthersDraft,
        logMessageHidden,
        privateDraftForStatus,
    }
    src.lib.mailboxes.access --> src.lib.user { getMailboxAccessLevel, listAccessibleMailboxIds }
    src.lib.mailboxes.audit --> src.lib.user { createAuditLog }
    "src/lib/auth/types.d" --> src.lib.user { SessionUser }
    src.lib.spam.feedback --> src.lib.user { applySpamFeedback }
    src.db.index --> src.lib.spam.feedback { getDb }
    src.db.schema.index --> src.lib.spam.feedback {
        messages,
        spamFeedback,
        spamReputation,
        spamTokenStats,
    }
    src.db.sql --> src.lib.spam.feedback { excluded, greatest }
    src.lib.mailboxes.access --> src.lib.spam.feedback { getMailboxAccessLevel }
    "src/lib/mailboxes/types.d" --> src.lib.spam.feedback { MailboxAccessLevel }
    "src/lib/auth/types.d" --> src.lib.spam.feedback { SessionUser }
    src.lib.mailboxes.audit --> src.lib.spam.feedback { createAuditLog }
    src.lib.spam.tokenizer --> src.lib.spam.feedback {
        buildFingerprint,
        prepareSpamContent,
        tokenizeMessage,
    }
    src.lib.spam.analyzers.reputation --> src.lib.spam.feedback { getReputationKeys }
    "src/lib/spam/types.d" --> src.lib.spam.feedback { ReputationKey, SpamClassification }
    src.lib.spam.weights --> src.lib.spam.feedback { TOKENIZER_VERSION }
    src.db.index --> src.lib.agent.reply { getDb }
    src.lib.email.address --> src.lib.agent.reply { getEmailAddressList, normalizeEmailAddress }
    "src/lib/mailboxes/domain-addresses" --> src.lib.agent.reply { getMailboxDomainAddresses }
    src.lib.mailboxes.access --> src.lib.agent.reply { getMailboxAccessLevel }
    "src/lib/agent/types.d" --> src.lib.agent.reply { AgentToolContext }
    src.db.schema.index --> src.lib.agent.reply { messages }
    "src/components/compose/rich-text-utils" --> "src/lib/agent/draft-format" { textToHtml }
    "src/app/(dashboard)/inbox/[messageId]/email-html-sanitizer" --> "src/components/compose/rich-text-utils" {
        sanitizeEmailHtml,
    }
    src.lib.email.html --> "src/app/(dashboard)/inbox/[messageId]/email-html-sanitizer" {
        sanitizeEmailHtml,
    }
    "src/app/(dashboard)/inbox/[messageId]/email-html-sanitizer-types.d" --> src.lib.email.html {
        SanitizeEmailHtmlOptions,
    }
    "src/lib/email/draft-access" --> "src/lib/agent/edit-draft" { isOthersDraft }
    src.db.index --> "src/lib/agent/edit-draft" { getDb }
    src.db.schema.index --> "src/lib/agent/edit-draft" {
        agentDraftMetadata,
        messageAttachments,
        messages,
    }
    src.lib.email.parse --> "src/lib/agent/edit-draft" { buildSnippet }
    src.lib.email.sender --> "src/lib/agent/edit-draft" { getAuthorizedSenderAddress }
    src.lib.email.address --> "src/lib/agent/edit-draft" { getEmailAddress, splitEmailAddressList }
    src.lib.mailboxes.access --> "src/lib/agent/edit-draft" { getMailboxAccessLevel }
    "src/lib/email/attachment-policy" --> "src/lib/agent/edit-draft" { getOutboundAttachmentMaxMb }
    src.lib.email.attachments --> "src/lib/agent/edit-draft" {
        MAX_ATTACHMENT_COUNT,
        deleteMessageAttachment,
        getAttachmentForUser,
        storeMessageAttachments,
    }
    "src/lib/email/attachment-types.d" --> "src/lib/agent/edit-draft" { AttachmentContent }
    "src/lib/agent/types.d" --> "src/lib/agent/edit-draft" { AgentDraftEditInput, AgentToolContext }
    "src/lib/agent/draft-format" --> "src/lib/agent/edit-draft" { formatAgentDraftBody }
    src.lib.agent.schedule --> "src/lib/agent/edit-draft" { parseAgentScheduledAt }
    src.db.index --> src.lib.agent.approvals.utils { getDb }
    src.db.schema.index --> src.lib.agent.approvals.utils {
        agentDraftMetadata,
        agentSendApprovals,
        contacts,
        messageAttachments,
        messages,
    }
    src.lib.email.address --> src.lib.agent.approvals.utils {
        getEmailAddress,
        splitEmailAddressList,
    }
    src.lib.email.sender --> src.lib.agent.approvals.utils { getAuthorizedSenderAddress }
    src.lib.email.attachments --> src.lib.agent.approvals.utils { loadMessageAttachmentContents }
    src.lib.email.send --> src.lib.agent.approvals.utils { sendEmail }
    src.lib.ids --> src.lib.agent.approvals.utils { newId }
    "src/lib/auth/types.d" --> src.lib.agent.approvals.utils { SessionUser }
    "src/lib/agent/approvals/types.d" --> src.lib.agent.approvals.utils { AgentSendSnapshot }
    src.lib.promotions.settings --> "src/lib/promotions/mode-utils" { PromotionMode }
    src.lib.contacts.utils ++> "src/lib/email/inbound-notification" { getPartyDisplayName }
    src.db.index --> src.lib.promotions.classify { getDb }
    src.db.schema.index --> src.lib.promotions.classify { mailboxSenderPreferences }
    "src/lib/database-errors" --> src.lib.promotions.classify { isMissingTableError }
    "src/lib/email/bulk-mail" --> src.lib.promotions.classify { MailHeaders, detectBulkMail }
    "src/lib/promotions/classify-utils" --> src.lib.promotions.classify {
        decideCategory,
        toSenderAddress,
    }
    src.db.index --> src.lib.import.jobs { getDb }
    src.db.schema.index --> src.lib.import.jobs { importJobs, mailboxes, users }
    src.lib.mailboxes.access --> src.lib.import.jobs { getMailboxAccessLevel }
    src.lib.ids --> src.lib.import.jobs { newId }
    src.lib.import.destination --> src.lib.import.jobs {
        getImportMessageUserId,
        parseImportDestination,
    }
    src.lib.import.imap --> src.lib.import.jobs { fetchImapMessages }
    "src/lib/import/imap-utils" --> src.lib.import.jobs {
        getImapChunkSize,
        growImapChunkSize,
        isImapConnectionError,
        isMissingImapFolderError,
        isPermanentImapError,
        keepsImapChunkSize,
    }
    src.lib.import.staging --> src.lib.import.jobs {
        deleteStagedImport,
        importBatchKey,
        stageImportMessages,
        unpackImportMessages,
    }
    src.lib.import.service --> src.lib.import.jobs { importMessagesToMailbox }
    "src/lib/import/jobs-types.d" --> src.lib.import.jobs {
        FileImportCursor,
        FileImportSpec,
        ImapImportCursor,
        ImapImportSource,
        ImapImportSpec,
        ImportJobMessage,
        ImportJobSummary,
    }
    "src/lib/import/types.d" --> src.lib.import.jobs { ImportMailboxResult, ImportMessageInput }
    "src/lib/import/destination-types.d" --> src.lib.import.destination {
        ImportDestination,
        ImportMessagePlacement,
        ImportSystemSection,
    }
    "src/lib/import/types.d" --> src.lib.import.imap { ImportMessageInput }
    "src/lib/import/imap-types.d" --> src.lib.import.imap { ImapImportInput }
    "src/lib/import/imap-utils" --> src.lib.import.imap {
        assertSafeImapHost,
        encodeImapMailboxName,
        getLiteralLength,
        isTaggedCompletion,
        parseFetchFlags,
        parseListMailboxName,
        parseSearchUids,
        planImapFetchGroups,
        quoteImapString,
        selectImapUidBatch,
    }
    "src/lib/import/types.d" --> src.lib.import.staging { ImportMessageInput }
    src.db.index --> src.lib.import.service { getDb }
    src.db.schema.index --> src.lib.import.service { messages }
    src.lib.email.attachments --> src.lib.import.service { storeMessageAttachments }
    "src/lib/email/message-cleanup" --> src.lib.import.service { deleteMessageWithObjects }
    src.lib.email.parse --> src.lib.import.service { buildSnippet, parseRawMime }
    src.lib.email.threading --> src.lib.import.service { resolveThreadId }
    src.lib.contacts.service --> src.lib.import.service { upsertContactFromAddress }
    src.lib.ids --> src.lib.import.service { newId }
    src.lib.import.destination --> src.lib.import.service { getImportMessagePlacement }
    "src/lib/import/destination-types.d" --> src.lib.import.service { ImportDestination }
    "src/lib/import/message-hints-utils" --> src.lib.import.service {
        applyImportHints,
        getImportMessageHints,
    }
    "src/lib/import/types.d" --> src.lib.import.service { ImportMailboxResult, ImportMessageInput }
    src.db.index --> src.lib.dav.handler { getDb }
    src.db.schema.index --> src.lib.dav.handler { domains, mailboxes }
    "src/lib/auth/app-passwords" --> src.lib.dav.handler { authenticateAppPasswordRequest }
    src.lib.security.headers --> src.lib.dav.handler { getSecurityHeaders }
    src.lib.dav.body --> src.lib.dav.handler { MAX_XML_BODY, readBodyText }
    src.lib.dav.settings --> src.lib.dav.handler { isDavEnabled }
    src.lib.dav.xml --> src.lib.dav.handler { DavElement, DavXmlError, parseDavXml }
    "src/lib/dav/xml-writer" --> src.lib.dav.handler {
        DavPropstat,
        DavResponse,
        escapeXml,
        multistatus,
    }
    "src/db/with-database" --> "worker-utils" { getDatabaseConfig }
    "src/lib/d1-session-context" --> "worker-utils" { withD1Session }
    "src/lib/database-errors" --> "worker-utils" { isMissingColumnError, isMissingTableError }
    src.lib.email.inbound --> "worker-utils" { InboundQueueMessage }
    src.lib.email.webhooks --> "worker-utils" { WebhookRetryMessage }
    "src/lib/import/jobs-types.d" --> "worker-utils" { ImportJobMessage }
    "src/db/with-database" --> server.runtime.env { getDatabaseConfig, withDatabase }
    src.lib.storage.index --> server.runtime.env { withStorage }
    "server/runtime/file-bucket" --> server.runtime.env { openFileBucket }
    server.runtime.mailer --> server.runtime.env { Mailer, MailerConfig, openMailer }
    server.runtime.misc --> server.runtime.env { openAssets, openRateLimiter }
    server.runtime.queue --> server.runtime.env { InProcessQueue, openQueue }
    server.runtime.realtime --> server.runtime.env { RealtimeHubRegistry }
    "server/runtime/sqlite-database" --> server.runtime.env { SqliteDatabase, openSqliteDatabase }
    "server/runtime/types.d" --> server.runtime.env { NodeRuntime }
    src.lib.auth.origin --> "server/runtime/realtime-origin" { hasValidSessionMutationOrigin }
    "server/runtime/sqlite-database" --> server.runtime.migrate { SqliteDatabase }
    src.lib.backups.runner --> server.runtime.scheduler { runScheduledDatabaseBackup }
    src.lib.agent.maintenance --> server.runtime.scheduler { runAgentMaintenance }
    "src/lib/email/trash-retention" --> server.runtime.scheduler { runTrashRetention }
    src.lib.drive.retention --> server.runtime.scheduler { runDriveTrashRetention }
    src.lib.accounts.deletion --> server.runtime.scheduler { runAccountRetention }
    src.lib.auth.purge --> server.runtime.scheduler { purgeExpiredAuthRows }
    src.lib.jmap.changes --> server.runtime.scheduler { runJmapChangeRetention }
    src.lib.dav.changes --> server.runtime.scheduler { runDavChangeRetention }
    "src/lib/follow-ups/service" --> server.runtime.scheduler { runFollowUpReminders }
    src.lib.calendar.reminders --> server.runtime.scheduler { runCalendarReminders }
    src.lib.promotions.backfill --> server.runtime.scheduler { runPromotionsBackfill }
    src.lib.import.jobs --> server.runtime.scheduler { sweepImportJobs }
    "src/lib/email/raw-sweeper" --> server.runtime.scheduler { sweepOrphanedRawMail }
    src.lib.deliverability.daily --> server.runtime.scheduler { runDeliverabilityDaily }
    src.lib.messages.actions.claims --> server.runtime.scheduler {
        pruneExpiredMessageActionUndoClaims,
    }
    src.db.index --> src.lib.backups.runner { getDb }
    src.db.schema.index --> src.lib.backups.runner { backups }
    src.lib.backups.export --> src.lib.backups.runner { exportDatabaseRecords }
    src.lib.backups.service --> src.lib.backups.runner {
        createScheduledBackupIfDue,
        getBackupSettings,
    }
    src.lib.backups.utils --> src.lib.backups.runner { BACKUP_PREFIX, createBackupFilename }
    src.db.index --> src.lib.backups.service { getDb }
    src.db.schema.index --> src.lib.backups.service { backupSettings, backups }
    src.lib.ids --> src.lib.backups.service { newId }
    "src/lib/backups/types.d" --> src.lib.backups.service { BackupScheduleType, BackupTableGroupId }
    src.lib.backups.utils --> src.lib.backups.service {
        BACKUP_SETTINGS_ID,
        getUtcDayBounds,
        isBackupDue,
    }
    "src/lib/backups/table-groups" --> src.lib.backups.service { parseExcludedBackupTableGroups }
    src.db.index --> src.lib.agent.maintenance { getDb }
    src.db.schema.index --> src.lib.agent.maintenance { agentConversations, agentSendApprovals }
    src.lib.agent.jobs.utils --> src.lib.agent.maintenance { recoverAgentDraftJobs }
    src.db.index --> "src/lib/email/trash-retention" { getDb }
    src.db.schema.index --> "src/lib/email/trash-retention" { messages, users }
    "src/lib/email/permanent-delete" --> "src/lib/email/trash-retention" {
        permanentlyDeleteMessages,
    }
    "src/lib/email/trash-retention-utils" --> "src/lib/email/trash-retention" {
        TRASH_RETENTION_BATCH_SIZE,
        getTrashRetentionCutoff,
        normalizeTrashRetentionDays,
    }
    src.db.index --> "src/lib/email/permanent-delete" { AppDatabase }
    "src/lib/email/message-cleanup" --> "src/lib/email/permanent-delete" {
        deleteMessageWithObjects,
    }
    src.lib.mailboxes.audit --> "src/lib/email/permanent-delete" { createAuditLog }
    src.lib.i18n.utils ++> "src/lib/email/trash-retention-utils" { defaultTranslator }
    src.db.index --> src.lib.drive.retention { getDb }
    src.db.schema.index --> src.lib.drive.retention { driveItems, messageAttachments }
    src.lib.drive.access --> src.lib.drive.retention { deleteDriveItems }
    "src/lib/drive/shared-objects" --> src.lib.drive.retention { deleteUnreferencedObjects }
    src.db.index --> src.lib.drive.access { getDb }
    src.db.schema.index --> src.lib.drive.access {
        driveItems,
        driveShares,
        driveUploadParts,
        users,
    }
    src.lib.drive.utils --> src.lib.drive.access { DRIVE_MAX_DEPTH, driveObjectKey }
    "src/lib/drive/types.d" --> src.lib.drive.access { DriveItemDto, DriveRole, DriveRow }
    "src/lib/drive/shared-objects" --> src.lib.drive.access { deleteUnreferencedObjects }
    src.db.index --> src.lib.accounts.deletion { getDb }
    src.db.schema.index --> src.lib.accounts.deletion {
        calendarEvents,
        driveItems,
        mailboxes,
        messageAttachments,
        messages,
        sessions,
        users,
    }
    src.lib.auth.admin --> src.lib.accounts.deletion { canManageUsers, isPrimaryAdmin }
    "src/lib/auth/types.d" --> src.lib.accounts.deletion { SessionUser }
    src.lib.drive.access --> src.lib.accounts.deletion { deleteDriveItems }
    src.lib.drive.utils --> src.lib.accounts.deletion { driveObjectKey }
    src.lib.ids --> src.lib.accounts.deletion { newId }
    src.lib.licenses.seats --> src.lib.accounts.deletion { getAccountSeatError }
    "src/lib/mailboxes/domain-addresses" --> src.lib.accounts.deletion {
        removeMailboxDomainRouting,
    }
    src.app.api.profile.avatar.utils --> src.lib.accounts.deletion { avatarKeyFor }
    "src/lib/accounts/deletion-utils" --> src.lib.accounts.deletion { getAccountPurgeCutoff }
    "src/lib/accounts/deletion-types.d" --> src.lib.accounts.deletion {
        DeleteAccountsInput,
        DeleteAccountsResult,
    }
    "src/lib/drive/shared-objects" --> src.lib.accounts.deletion { deleteUnreferencedObjects }
    "src/lib/auth/types.d" --> src.lib.auth.admin { SessionUser }
    src.db.index --> src.lib.licenses.seats { getDb }
    src.db.schema.index --> src.lib.licenses.seats { users }
    src.lib.licenses.service --> src.lib.licenses.seats { getLicenseEntitlements }
    src.db.index --> src.lib.licenses.service { getDb }
    src.db.schema.index --> src.lib.licenses.service { licenseSettings }
    src.lib.licenses.constants --> src.lib.licenses.service { LICENSE_PRODUCT_IDS }
    src.lib.licenses.paymug --> src.lib.licenses.service { callPaymugLicenseApi }
    "src/lib/licenses/types.d" --> src.lib.licenses.service {
        LicenseEntitlements,
        LicensePlan,
        LicenseStatus,
        PaymugLicenseAction,
    }
    src.lib.licenses.utils --> src.lib.licenses.service {
        hashLicenseKey,
        normalizeLicensePlan,
        parseFeatures,
    }
    "src/lib/licenses/types.d" --> src.lib.licenses.constants { LicensePlan }
    "src/lib/licenses/types.d" --> src.lib.licenses.paymug {
        LicenseActivationInput,
        LicenseDeactivationInput,
        PaymugLicenseAction,
        PaymugLicenseResponse,
    }
    src.lib.licenses.utils --> src.lib.licenses.paymug { parsePaymugLicenseResponse }
    "src/lib/licenses/types.d" --> src.lib.licenses.utils {
        LicensePlan,
        LicenseState,
        PaymugLicenseResponse,
    }
    src.lib.licenses.constants --> src.lib.licenses.utils { LICENSE_PRODUCT_IDS }
    "src/app/api/profile/avatar/types.d" --> src.app.api.profile.avatar.utils { UploadedAvatarFile }
    src.db.index --> src.lib.auth.purge { getDb }
    src.db.schema.index --> src.lib.auth.purge {
        loginChallenges,
        passkeyEnrollmentGrants,
        passwordResetTokens,
        sessions,
    }
    src.db.index --> src.lib.dav.changes { getDb }
    src.db.schema.index --> src.lib.dav.changes { davChanges, davSyncState }
    src.db.sql --> src.lib.dav.changes { excluded, greatest }
    "src/lib/database-errors" --> src.lib.dav.changes { isMissingTableError }
    src.db.index --> src.lib.calendar.reminders { getDb }
    src.db.schema.index --> src.lib.calendar.reminders {
        calendarEventOverrides,
        calendarEvents,
        users,
    }
    "src/lib/database-errors" --> src.lib.calendar.reminders { isMissingColumnError }
    src.lib.push.server --> src.lib.calendar.reminders { sendPushContent }
    src.lib.time.utils --> src.lib.calendar.reminders { normalizeTimeZone }
    src.lib.calendar.chunks --> src.lib.calendar.reminders { chunkIds }
    "src/lib/calendar/reminder-utils" --> src.lib.calendar.reminders {
        MAX_REMINDER_MINUTES,
        REMINDER_GRACE_MS,
        dueReminderOccurrences,
        formatReminderBody,
    }
    src.db.index --> "src/lib/email/raw-sweeper" { getDb }
    src.db.schema.index --> "src/lib/email/raw-sweeper" { messages }
    "src/lib/email/intake-signature" --> "src/lib/email/raw-sweeper" {
        INBOUND_SIGNATURE_MAX_AGE_SECONDS,
    }
    "src/lib/aws/sns-signature" --> "src/lib/email/raw-sweeper" { SNS_MAX_AGE_MS }
    src.lib.jmap.blobs --> "src/lib/email/raw-sweeper" { UPLOAD_PREFIX }
    "src/lib/email/stale-objects" --> "src/lib/email/raw-sweeper" { sweepStaleObjects }
    "src/lib/aws/ses-notification" --> "src/lib/aws/sns-signature" { SnsEnvelope }
    "src/lib/spam/types.d" --> "src/lib/aws/ses-notification" { ProviderVerdicts }
    src.db.index --> src.lib.messages.actions.claims { getDb }
    src.db.schema.index --> src.lib.messages.actions.claims { messageActionUndoClaims }
    "src/lib/database-errors" --> src.lib.messages.actions.claims { isUniqueConstraintError }
    src.lib.email.intake --> server.runtime.smtp { intakeIncomingMail }
    "src/lib/email/inbound-attachments" --> server.runtime.smtp {
        inboundAttachmentLimitReasonFromRaw,
    }
    src.lib.email.routing --> server.runtime.smtp { recordRuleMatch, resolveInboundAddress }
    "src/lib/spam/domain-utils" --> server.runtime.smtp { isPublicIpv4 }
    src.db.index --> server.runtime.smtp { getDb }
    src.db.schema.index --> server.runtime.smtp { domains }
    "server/runtime/smtp-auth" --> server.runtime.smtp { verifySmtpAuthentication }
    server.runtime.mailer --> server.runtime.smtp { Mailer }
    "src/lib/email/account-forwarding" --> src.lib.email.intake {
        MAILFLARE_FORWARDED_HEADER,
        forwardedMarker,
        getAccountForwardingDestination,
        isForwardedMarkerValid,
    }
    src.lib.email.incoming --> src.lib.email.intake { resolveIncomingMail }
    "src/lib/email/inbound-id" --> src.lib.email.intake { inboundStorageKey }
    src.lib.email.inbound --> src.lib.email.intake { InboundQueueMessage }
    "src/lib/email/intake-types.d" --> src.lib.email.intake {
        IntakeActions,
        IntakeInput,
        IntakeResult,
    }
    src.db.index --> "src/lib/email/account-forwarding" { getDb }
    src.db.schema.index --> "src/lib/email/account-forwarding" { users }
    src.lib.email.address --> "src/lib/email/account-forwarding" { getEmailAddress }
    src.lib.email.routing --> "src/lib/email/account-forwarding" { resolveInboundAddress }
    src.lib.licenses.service --> "src/lib/email/account-forwarding" { getLicenseEntitlements }
    src.db.index --> src.lib.email.incoming { getDb }
    src.lib.email.routing --> src.lib.email.incoming {
        RoutingDecision,
        recordRuleMatch,
        resolveInboundAddress,
    }
    "src/lib/deliverability/report-address" --> src.lib.email.incoming { matchReportAddress }
    "src/lib/email/account-forwarding" --> src.lib.email.incoming {
        MAILFLARE_FORWARDED_HEADER,
        forwardedMarker,
    }
    "src/lib/spam/types.d" --> "server/runtime/smtp-auth" { ProviderVerdicts }
    "src/components/accounts/account-settings-nav" --> "src/app/(admin)/accounts/[id]/layout" {
        AccountSettingsNav,
    }
    "src/components/language-provider" --> "src/components/accounts/account-settings-nav" {
        useLanguage,
    }
    src.lib.utils --> "src/components/accounts/account-settings-nav" { cn }
    "src/components/section-nav-sheet" --> "src/components/accounts/account-settings-nav" {
        SectionNavSheet,
    }
    "src/components/accounts/account-settings-nav-utils" --> "src/components/accounts/account-settings-nav" {
        accountSettingsNavItems,
        getAccountSettingsHref,
        isActiveAccountSettingsPath,
    }
    src.lib.i18n.utils --> "src/components/language-provider" {
        DEFAULT_LOCALE,
        createTranslator,
        getDirection,
        loadMessages,
        resolveLocale,
        serializeLocaleCookie,
    }
    "src/lib/i18n/types.d" --> "src/components/language-provider" { Locale, Messages }
    "src/components/language-provider-types.d" --> "src/components/language-provider" {
        LanguageState,
    }
    src.components.icons --> "src/components/section-nav-sheet" { ChevronUp }
    "src/components/sidebar-mobile-utils" --> "src/components/section-nav-sheet" { useIsMobile }
    "src/components/accounts/account-settings-nav-types.d" --> "src/components/accounts/account-settings-nav-utils" {
        AccountSettingsNavItem,
    }
    src.components.icons --> "src/app/(admin)/accounts/[id]/mailboxes/page" { Plus, Trash2 }
    "src/components/language-provider" --> "src/app/(admin)/accounts/[id]/mailboxes/page" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/accounts/[id]/mailboxes/page" { Button }
    src.components.ui.input --> "src/app/(admin)/accounts/[id]/mailboxes/page" { Input }
    src.components.ui.select --> "src/app/(admin)/accounts/[id]/mailboxes/page" { Select }
    src.components.ui.label --> "src/app/(admin)/accounts/[id]/mailboxes/page" { Label }
    "src/app/(admin)/accounts/[id]/types.d" --> "src/app/(admin)/accounts/[id]/mailboxes/page" {
        ManagedAccount,
        ManagedDomain,
        ManagedMailbox,
    }
    "src/app/(admin)/accounts/[id]/utils" --> "src/app/(admin)/accounts/[id]/mailboxes/page" {
        addManagedMailbox,
        fetchManagedAccount,
        fetchManagedDomains,
        fetchManagedMailboxes,
        removeManagedMailbox,
    }
    src.lib.utils --> src.components.ui.input { cn }
    src.components.icons --> src.components.ui.select { Check, ChevronDown }
    src.lib.utils --> src.components.ui.select { cn }
    "src/components/ui/select-types.d" --> src.components.ui.select { SelectProps }
    src.lib.utils --> src.components.ui.label { cn }
    src.lib.auth.client --> "src/app/(admin)/accounts/[id]/utils" { authFetch }
    "src/lib/http/client-error" --> "src/app/(admin)/accounts/[id]/utils" { requestError }
    "src/lib/avatar-upload-client" --> "src/app/(admin)/accounts/[id]/utils" {
        appendOptimizedAvatar,
    }
    "src/app/(admin)/accounts/[id]/types.d" --> "src/app/(admin)/accounts/[id]/utils" {
        AccountDetail,
        AccountDetailResponse,
        AccountMailboxAccessItem,
        AccountMailboxAccessResponse,
        AccountMailboxItem,
        DomainOption,
        ManagedAccount,
        ManagedDomain,
        ManagedMailbox,
    }
    src.components.icons --> "src/app/(admin)/accounts/[id]/page" { Upload }
    "src/components/language-provider" --> "src/app/(admin)/accounts/[id]/page" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/accounts/[id]/page" { Button }
    src.components.ui.switch --> "src/app/(admin)/accounts/[id]/page" { Switch }
    src.components.ui.input --> "src/app/(admin)/accounts/[id]/page" { Input }
    "src/components/progressive-avatar-image" --> "src/app/(admin)/accounts/[id]/page" {
        ProgressiveAvatarImage,
    }
    src.components.ui.label --> "src/app/(admin)/accounts/[id]/page" { Label }
    "src/components/settings/security-status-store" --> "src/app/(admin)/accounts/[id]/page" {
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/app/(admin)/accounts/[id]/page" {
        StepUpDialog,
    }
    "src/app/(admin)/accounts/[id]/types.d" --> "src/app/(admin)/accounts/[id]/page" {
        ManagedAccount,
    }
    "src/app/(admin)/accounts/[id]/utils" --> "src/app/(admin)/accounts/[id]/page" {
        fetchManagedAccount,
        getManagedAccountAvatarUrl,
        saveManagedAccount,
        uploadManagedAccountAvatar,
    }
    src.lib.utils --> src.components.ui.switch { cn }
    "src/components/ui/switch-types.d" --> src.components.ui.switch { SwitchProps }
    "src/components/progressive-avatar-image-types.d" --> "src/components/progressive-avatar-image" {
        ProgressiveAvatarImageProps,
    }
    "src/components/progressive-avatar-image-utils" --> "src/components/progressive-avatar-image" {
        getAvatarPreviewUrl,
        rememberAvatarLoaded,
        wasAvatarLoaded,
    }
    src.lib.auth.client --> "src/components/settings/security-status-store" {
        AUTH_SESSION_CHANGED_EVENT,
        authFetch,
    }
    "src/components/settings/passkey-settings-types.d" --> "src/components/settings/security-status-store" {
        SecurityStatus,
    }
    src.components.icons --> "src/components/settings/step-up-dialog" { KeyRound, ShieldCheck }
    "src/components/language-provider" --> "src/components/settings/step-up-dialog" { useLanguage }
    src.components.ui.button --> "src/components/settings/step-up-dialog" { Button }
    src.components.ui.dialog --> "src/components/settings/step-up-dialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/settings/step-up-dialog" { Input }
    src.components.ui.label --> "src/components/settings/step-up-dialog" { Label }
    "src/lib/auth/error-messages" --> "src/components/settings/step-up-dialog" { authErrorText }
    "src/lib/auth/webauthn/browser-errors" --> "src/components/settings/step-up-dialog" {
        isPasskeyCancellation,
    }
    "src/lib/http/client-error" --> "src/components/settings/step-up-dialog" { ClientRequestError }
    "src/components/settings/passkey-settings-utils" --> "src/components/settings/step-up-dialog" {
        stepUpWithPasskey,
        stepUpWithPassword,
    }
    src.components.icons --> src.components.ui.dialog { X }
    src.lib.utils --> src.components.ui.dialog { cn }
    "src/components/language-provider" --> src.components.ui.dialog { useLanguage }
    "src/lib/i18n/types.d" --> "src/lib/auth/error-messages" { TranslationKey }
    "src/lib/auth/error-codes" --> "src/lib/auth/error-messages" { AuthErrorCode }
    src.lib.auth.client --> "src/components/settings/passkey-settings-utils" { authFetch }
    "src/lib/http/client-error" --> "src/components/settings/passkey-settings-utils" {
        requestError,
    }
    "src/components/settings/passkey-settings-types.d" --> "src/components/settings/passkey-settings-utils" {
        PasskeyAddResponse,
        PasskeyCheckResponse,
        PasskeyOptionsResponse,
        RemovePasswordResponse,
        SecurityStatus,
        StepUpResponse,
    }
    src.components.icons --> "src/app/(admin)/accounts/[id]/password/page" { Copy, KeyRound }
    "src/components/language-provider" --> "src/app/(admin)/accounts/[id]/password/page" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/accounts/[id]/password/page" { Button }
    src.components.ui.dialog --> "src/app/(admin)/accounts/[id]/password/page" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/app/(admin)/accounts/[id]/password/page" { Input }
    src.components.ui.label --> "src/app/(admin)/accounts/[id]/password/page" { Label }
    "src/components/settings/step-up-dialog" --> "src/app/(admin)/accounts/[id]/password/page" {
        StepUpDialog,
    }
    "src/components/settings/passkey-settings-utils" --> "src/app/(admin)/accounts/[id]/password/page" {
        loadSecurityStatus,
    }
    "src/components/settings/passkey-settings-types.d" --> "src/app/(admin)/accounts/[id]/password/page" {
        SecurityStatus,
    }
    src.lib.auth.client --> "src/app/(admin)/accounts/[id]/password/page" { authFetch }
    "src/lib/http/client-error" --> "src/app/(admin)/accounts/[id]/password/page" { requestError }
    "src/app/(admin)/accounts/[id]/types.d" --> "src/app/(admin)/accounts/[id]/password/page" {
        ManagedAccount,
    }
    "src/app/(admin)/accounts/[id]/utils" --> "src/app/(admin)/accounts/[id]/password/page" {
        fetchManagedAccount,
    }
    "src/app/(admin)/accounts/[id]/password/utils" --> "src/app/(admin)/accounts/[id]/password/page" {
        saveAccountPassword,
    }
    src.lib.i18n.utils --> "src/app/(admin)/accounts/[id]/password/utils" { defaultTranslator }
    "src/app/(admin)/accounts/[id]/utils" --> "src/app/(admin)/accounts/[id]/password/utils" {
        saveManagedAccount,
    }
    "src/app/(admin)/accounts/[id]/password/types.d" --> "src/app/(admin)/accounts/[id]/password/utils" {
        PasswordSaveOptions,
    }
    "src/components/language-provider" --> "src/app/(admin)/accounts/[id]/permissions/page" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/accounts/[id]/permissions/page" { Button }
    src.components.ui.checkbox --> "src/app/(admin)/accounts/[id]/permissions/page" { Checkbox }
    src.components.ui.select --> "src/app/(admin)/accounts/[id]/permissions/page" { Select }
    src.components.ui.dialog --> "src/app/(admin)/accounts/[id]/permissions/page" {
        Dialog,
        DialogClose,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    "src/components/progressive-avatar-image" --> "src/app/(admin)/accounts/[id]/permissions/page" {
        ProgressiveAvatarImage,
    }
    "src/lib/avatar-colors" --> "src/app/(admin)/accounts/[id]/permissions/page" {
        getAvatarColorStyle,
    }
    "src/hooks/use-current-user" --> "src/app/(admin)/accounts/[id]/permissions/page" {
        clearCurrentUserCache,
        useCurrentUser,
    }
    "src/app/(admin)/accounts/[id]/types.d" --> "src/app/(admin)/accounts/[id]/permissions/page" {
        ManagedAccount,
    }
    "src/app/(admin)/accounts/[id]/utils" --> "src/app/(admin)/accounts/[id]/permissions/page" {
        TransferCandidate,
        fetchManagedAccount,
        fetchTransferCandidates,
        saveManagedAccount,
        transferPrimaryAdmin,
    }
    src.lib.utils --> src.components.ui.checkbox { cn }
    "src/components/ui/checkbox-types.d" --> src.components.ui.checkbox { CheckboxProps }
    src.lib.auth.client --> "src/hooks/use-current-user" { AUTH_SESSION_CHANGED_EVENT, authFetch }
    src.components.icons --> "src/app/(admin)/accounts/account-aliases" { Plus, Trash2 }
    "src/components/language-provider" --> "src/app/(admin)/accounts/account-aliases" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/accounts/account-aliases" { Button }
    src.components.ui.checkbox --> "src/app/(admin)/accounts/account-aliases" { Checkbox }
    src.components.ui.input --> "src/app/(admin)/accounts/account-aliases" { Input }
    src.components.ui.select --> "src/app/(admin)/accounts/account-aliases" { Select }
    "src/app/(admin)/accounts/types.d" --> "src/app/(admin)/accounts/account-aliases" {
        AccountAliasesProps,
    }
    src.components.icons --> "src/app/(admin)/accounts/accounts-table" {
        MoreVertical,
        RotateCcw,
        Trash2,
    }
    "src/components/language-provider" --> "src/app/(admin)/accounts/accounts-table" { useLanguage }
    "src/components/progressive-avatar-image" --> "src/app/(admin)/accounts/accounts-table" {
        ProgressiveAvatarImage,
    }
    src.components.ui.button --> "src/app/(admin)/accounts/accounts-table" { Button }
    src.components.ui.checkbox --> "src/app/(admin)/accounts/accounts-table" { Checkbox }
    "src/lib/avatar-colors" --> "src/app/(admin)/accounts/accounts-table" { getAvatarColorStyle }
    "src/lib/accounts/deletion-utils" --> "src/app/(admin)/accounts/accounts-table" {
        getAccountPurgeDate,
        getAccountStatus,
    }
    "src/app/(admin)/accounts/utils" --> "src/app/(admin)/accounts/accounts-table" {
        formatAccountDate,
        formatAccountDateTime,
    }
    "src/app/(admin)/accounts/accounts-table-types.d" --> "src/app/(admin)/accounts/accounts-table" {
        AccountsTableProps,
    }
    "src/app/(admin)/accounts/types.d" --> "src/app/(admin)/accounts/utils" { Account }
    "src/components/language-provider" --> "src/app/(admin)/accounts/delete-accounts-dialog" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/accounts/delete-accounts-dialog" { Button }
    src.components.ui.dialog --> "src/app/(admin)/accounts/delete-accounts-dialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.label --> "src/app/(admin)/accounts/delete-accounts-dialog" { Label }
    src.components.ui.select --> "src/app/(admin)/accounts/delete-accounts-dialog" { Select }
    src.lib.auth.client --> "src/app/(admin)/accounts/delete-accounts-dialog" { authFetch }
    "src/lib/accounts/deletion-utils" --> "src/app/(admin)/accounts/delete-accounts-dialog" {
        ACCOUNT_RESTORE_DAYS,
    }
    "src/app/(admin)/accounts/accounts-table-types.d" --> "src/app/(admin)/accounts/delete-accounts-dialog" {
        DeleteAccountsDialogProps,
    }
    "src/components/page-header-utils" --> "src/app/(admin)/accounts/page" {
        mobilePrimaryActionClass,
    }
    src.components.icons --> "src/app/(admin)/accounts/page" { Plus }
    "src/components/language-provider" --> "src/app/(admin)/accounts/page" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/accounts/page" { Button }
    src.components.ui.dialog --> "src/app/(admin)/accounts/page" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/app/(admin)/accounts/page" { Input }
    src.components.ui.label --> "src/app/(admin)/accounts/page" { Label }
    src.components.ui.select --> "src/app/(admin)/accounts/page" { Select }
    src.lib.auth.client --> "src/app/(admin)/accounts/page" { authFetch }
    "src/components/license-required-overlay" --> "src/app/(admin)/accounts/page" {
        LicenseRequiredOverlay,
    }
    "src/hooks/use-current-user" --> "src/app/(admin)/accounts/page" { useCurrentUser }
    src.lib.i18n.utils --> "src/app/(admin)/accounts/page" { defaultTranslator }
    "src/app/(admin)/accounts/account-aliases" --> "src/app/(admin)/accounts/page" {
        AccountAliases,
    }
    "src/app/(admin)/accounts/accounts-table" --> "src/app/(admin)/accounts/page" { AccountsTable }
    "src/app/(admin)/accounts/delete-accounts-dialog" --> "src/app/(admin)/accounts/page" {
        DeleteAccountsDialog,
    }
    "src/app/(admin)/accounts/types.d" --> "src/app/(admin)/accounts/page" {
        Account,
        AccountAliasDraft,
        AccountResponse,
        Domain,
    }
    src.components.icons --> "src/components/license-required-overlay" { LockKeyhole }
    src.components.ui.button --> "src/components/license-required-overlay" { Button }
    "src/components/language-provider" --> "src/components/license-required-overlay" { useLanguage }
    "src/components/license-required-overlay-types.d" --> "src/components/license-required-overlay" {
        LicenseRequiredOverlayProps,
    }
    src.components.icons --> "src/app/(admin)/activity/page" { LogIn, LogOut }
    "src/components/language-provider" --> "src/app/(admin)/activity/page" { useLanguage }
    src.components.ui.badge --> "src/app/(admin)/activity/page" { Badge }
    src.components.ui.skeleton --> "src/app/(admin)/activity/page" { Skeleton }
    "src/app/(admin)/activity/utils" --> "src/app/(admin)/activity/page" {
        fetchActivity,
        formatActivityDate,
        getActivityLabel,
        getActivityMetadata,
    }
    src.lib.utils --> src.components.ui.badge { cn }
    src.lib.utils --> src.components.ui.skeleton { cn }
    "src/components/ui/skeleton-types.d" --> src.components.ui.skeleton {
        SkeletonProps,
        SkeletonRowsProps,
    }
    src.lib.i18n.utils --> "src/app/(admin)/activity/utils" { Translator, defaultTranslator }
    src.lib.auth.client --> "src/app/(admin)/activity/utils" { authFetch }
    src.lib.time.utils --> "src/app/(admin)/activity/utils" { formatUserDate }
    "src/app/(admin)/activity/types.d" --> "src/app/(admin)/activity/utils" {
        ActivityLog,
        ActivityMetadata,
    }
    src.components.icons --> "src/app/(admin)/admin/page" {
        BadgeDollarSign,
        Bot,
        Globe2,
        KeyRound,
        Mail,
        Palette,
        Users,
    }
    "src/components/language-provider" --> "src/app/(admin)/admin/page" { useLanguage }
    "src/lib/i18n/types.d" --> "src/app/(admin)/admin/page" { TranslationKey }
    "src/components/admin-update-card" --> "src/app/(admin)/admin/page" { AdminUpdateCard }
    src.components.ui.card --> "src/app/(admin)/admin/page" { Card, CardContent, CardHeader }
    "src/hooks/use-current-user" --> "src/app/(admin)/admin/page" { useCurrentUser }
    src.components.icons --> "src/components/admin-update-card" {
        CheckCircle2,
        ChevronDown,
        CircleX,
        Database,
        RefreshCw,
    }
    "src/components/language-provider" --> "src/components/admin-update-card" { useLanguage }
    src.components.ui.card --> "src/components/admin-update-card" {
        Card,
        CardContent,
        CardHeader,
        CardTitle,
    }
    src.components.ui.switch --> "src/components/admin-update-card" { Switch }
    src.components.ui.skeleton --> "src/components/admin-update-card" { Skeleton }
    "src/components/admin-update-card-utils" --> "src/components/admin-update-card" {
        applyDatabaseMigrations,
        getApplicationUpdateStatus,
        getMigrationStatus,
        saveUpdateSettings,
        triggerApplicationUpdate,
    }
    "src/components/admin-update-card-types.d" --> "src/components/admin-update-card" {
        MigrationStatusResponse,
        UpdateStatusResponse,
        UpdateWorkflowResponse,
    }
    src.lib.utils --> src.components.ui.card { cn }
    "src/components/admin-update-card-types.d" --> "src/components/admin-update-card-utils" {
        MigrationStatusResponse,
        UpdateStatusResponse,
        UpdateWorkflowResponse,
    }
    src.components.icons --> "src/app/(admin)/agent/page" { Bot }
    "src/components/language-provider" --> "src/app/(admin)/agent/page" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/agent/page" { Button }
    src.components.ui.checkbox --> "src/app/(admin)/agent/page" { Checkbox }
    src.components.ui.card --> "src/app/(admin)/agent/page" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    src.components.ui.input --> "src/app/(admin)/agent/page" { Input }
    src.components.ui.label --> "src/app/(admin)/agent/page" { Label }
    src.components.ui.switch --> "src/app/(admin)/agent/page" { Switch }
    "src/lib/agent/provider-constants" --> "src/app/(admin)/agent/page" { DEFAULT_CLOUDFLARE_MODEL }
    "src/lib/agent/availability-client" --> "src/app/(admin)/agent/page" {
        saveAssistantAvailability,
    }
    "src/lib/agent/model-ids" --> "src/app/(admin)/agent/page" {
        parseAgentModelIds,
        toggleAgentModelId,
    }
    "src/lib/agent/provider-types.d" --> "src/app/(admin)/agent/page" {
        AgentModelOption,
        AgentProviderPreset,
    }
    "src/app/(admin)/agent/types.d" --> "src/app/(admin)/agent/page" { AgentAdminForm }
    "src/app/(admin)/agent/utils" --> "src/app/(admin)/agent/page" {
        PROVIDER_PRESETS,
        baseUrlForPreset,
        loadAgentAdminSettings,
        loadAgentModels,
        saveAgentAdminSettings,
        saveAgentEnabled,
        updateAgentModelRate,
    }
    src.components.ui.select --> "src/app/(admin)/agent/page" { Select }
    src.lib.auth.client --> "src/app/(admin)/agent/utils" { authFetch }
    "src/lib/agent/provider-constants" --> "src/app/(admin)/agent/utils" { PROVIDER_BASE_URLS }
    "src/lib/agent/provider-types.d" --> "src/app/(admin)/agent/utils" { AgentProviderPreset }
    "src/app/(admin)/agent/types.d" --> "src/app/(admin)/agent/utils" {
        AgentAdminForm,
        AgentAdminModelsResponse,
        AgentAdminSettingsResponse,
        AgentEnabledResponse,
    }
    "src/components/language-provider" --> "src/app/(admin)/ai-usage/page" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/ai-usage/page" { Button }
    "src/app/(admin)/ai-usage/types.d" --> "src/app/(admin)/ai-usage/page" { AiUsageResponse }
    "src/app/(admin)/ai-usage/utils" --> "src/app/(admin)/ai-usage/page" {
        fetchAiUsage,
        formatEstimatedUsd,
        formatTokenCount,
        formatUsageDate,
        formatUsageProvider,
    }
    "src/app/(admin)/ai-usage/usage-chart" --> "src/app/(admin)/ai-usage/page" { UsageChart }
    src.lib.auth.client --> "src/app/(admin)/ai-usage/utils" { authFetch }
    src.lib.time.utils --> "src/app/(admin)/ai-usage/utils" {
        formatUserDate,
        getUserTimeZone,
        recentZonedDays,
    }
    "src/app/(admin)/ai-usage/types.d" --> "src/app/(admin)/ai-usage/utils" {
        AiUsageDaily,
        AiUsageResponse,
    }
    "src/components/language-provider" --> "src/app/(admin)/ai-usage/usage-chart" { useLanguage }
    "src/app/(admin)/ai-usage/types.d" --> "src/app/(admin)/ai-usage/usage-chart" {
        UsageChartProps,
    }
    "src/app/(admin)/ai-usage/utils" --> "src/app/(admin)/ai-usage/usage-chart" {
        fillDailyUsage,
        formatDailyLabel,
        formatTokenCount,
    }
    src.lib.time.utils --> "src/app/(admin)/ai-usage/usage-chart" { getUserTimeZone }
    "src/components/page-header-utils" --> "src/app/(admin)/api-keys/page" {
        mobilePrimaryActionClass,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/api-keys/page" { confirmDestructive }
    src.components.icons --> "src/app/(admin)/api-keys/page" { Copy, KeyRound, Plus, Trash2 }
    "src/components/language-provider" --> "src/app/(admin)/api-keys/page" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/api-keys/page" { Button }
    src.components.ui.badge --> "src/app/(admin)/api-keys/page" { Badge }
    src.components.ui.dialog --> "src/app/(admin)/api-keys/page" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
        DialogTrigger,
    }
    src.components.ui.input --> "src/app/(admin)/api-keys/page" { Input }
    src.components.ui.label --> "src/app/(admin)/api-keys/page" { Label }
    src.components.ui.checkbox --> "src/app/(admin)/api-keys/page" { Checkbox }
    src.components.ui.list --> "src/app/(admin)/api-keys/page" { List, ListRow }
    "src/components/page-skeletons" --> "src/app/(admin)/api-keys/page" { SectionRowSkeleton }
    "src/components/settings/mcp-agent-instructions" --> "src/app/(admin)/api-keys/page" {
        McpAgentInstructions,
    }
    src.lib.auth.client --> "src/app/(admin)/api-keys/page" { authFetch }
    "src/lib/api/scopes-types.d" --> "src/app/(admin)/api-keys/page" { AdminApiKeyScope }
    "src/app/(admin)/api-keys/types.d" --> "src/app/(admin)/api-keys/page" { ApiKey }
    "src/app/(admin)/api-keys/utils" --> "src/app/(admin)/api-keys/page" {
        ADMIN_KEY_PERMISSIONS,
        parseApiKeyScopes,
    }
    "src/components/language-provider" --> "src/components/ui/confirm-dialog" { useLanguage }
    src.components.ui.button --> "src/components/ui/confirm-dialog" { Button }
    src.components.ui.dialog --> "src/components/ui/confirm-dialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/ui/confirm-dialog" { Input }
    "src/components/ui/confirm-dialog-types.d" --> "src/components/ui/confirm-dialog" {
        ConfirmOptions,
        ConfirmRequest,
    }
    src.lib.utils --> src.components.ui.list { cn }
    src.components.ui.skeleton --> "src/components/page-skeletons" { Skeleton, SkeletonRows }
    "src/components/route-loading-bar" --> "src/components/page-skeletons" { RouteLoadingBar }
    "src/components/language-provider" --> "src/components/route-loading-bar" { useLanguage }
    src.components.icons --> "src/components/settings/mcp-agent-instructions" { Copy }
    "src/components/language-provider" --> "src/components/settings/mcp-agent-instructions" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/settings/mcp-agent-instructions" { Button }
    "src/components/settings/mcp-agent-instructions-utils" --> "src/components/settings/mcp-agent-instructions" {
        buildMcpAgentPrompt,
    }
    "src/components/settings/mcp-agent-instructions-types.d" --> "src/components/settings/mcp-agent-instructions" {
        McpAgentInstructionsProps,
    }
    "src/components/settings/mcp-agent-instructions-types.d" --> "src/components/settings/mcp-agent-instructions-utils" {
        McpAgentInstructionsProps,
    }
    "src/lib/i18n/types.d" --> "src/app/(admin)/api-keys/utils" { TranslationKey }
    "src/lib/api/scopes-types.d" --> "src/app/(admin)/api-keys/utils" { AdminApiKeyScope }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/backups/page" { confirmDestructive }
    src.components.icons --> "src/app/(admin)/backups/page" {
        AlertTriangle,
        DatabaseBackup,
        Download,
        MoreVertical,
        Play,
        RefreshCw,
        Save,
        Settings,
        Trash2,
        Upload,
    }
    "src/components/language-provider" --> "src/app/(admin)/backups/page" { useLanguage }
    src.components.ui.badge --> "src/app/(admin)/backups/page" { Badge }
    src.components.ui.button --> "src/app/(admin)/backups/page" { Button }
    src.components.ui.card --> "src/app/(admin)/backups/page" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    src.components.ui.dialog --> "src/app/(admin)/backups/page" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/app/(admin)/backups/page" { Input }
    src.components.ui.label --> "src/app/(admin)/backups/page" { Label }
    src.components.ui.select --> "src/app/(admin)/backups/page" { Select }
    src.components.ui.skeleton --> "src/app/(admin)/backups/page" { SkeletonRows }
    src.components.ui.switch --> "src/app/(admin)/backups/page" { Switch }
    "src/lib/backups/table-groups" --> "src/app/(admin)/backups/page" { BACKUP_TABLE_GROUPS }
    "src/lib/i18n/types.d" --> "src/app/(admin)/backups/page" { TranslationKey }
    "src/app/(admin)/backups/types.d" --> "src/app/(admin)/backups/page" {
        BackupItem,
        BackupSettings,
    }
    "src/app/(admin)/backups/utils" --> "src/app/(admin)/backups/page" {
        WEEKDAYS,
        downloadBackup,
        fetchBackups,
        formatBackupDate,
        formatBackupSize,
        getStatusClass,
        removeBackup,
        restoreBackup,
        saveBackupSettings,
        startBackup,
    }
    src.lib.auth.client --> "src/app/(admin)/backups/utils" { authFetch }
    src.lib.time.utils --> "src/app/(admin)/backups/utils" { formatUserDate }
    "src/app/(admin)/backups/types.d" --> "src/app/(admin)/backups/utils" {
        BackupItem,
        BackupSettings,
        BackupsResponse,
    }
    src.components.icons --> "src/app/(admin)/branding/page" {
        ArrowRight,
        ExternalLink,
        ImagePlus,
        LockKeyhole,
        Palette,
    }
    "src/components/language-provider" --> "src/app/(admin)/branding/page" { useLanguage }
    "src/components/branding-provider" --> "src/app/(admin)/branding/page" { useBranding }
    src.components.ui.button --> "src/app/(admin)/branding/page" { Button }
    src.components.ui.card --> "src/app/(admin)/branding/page" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    src.components.ui.input --> "src/app/(admin)/branding/page" { Input }
    src.components.ui.label --> "src/app/(admin)/branding/page" { Label }
    "src/app/(admin)/branding/utils" --> "src/app/(admin)/branding/page" {
        BRANDING_ICON_ACCEPT,
        saveBranding,
    }
    "src/lib/branding/types.d" --> "src/components/branding-provider" { Branding }
    "src/components/branding-provider-types.d" --> "src/components/branding-provider" {
        BrandingContextValue,
    }
    "src/components/branding-provider-utils" --> "src/components/branding-provider" {
        DEFAULT_BRANDING,
        fetchBranding,
    }
    "src/lib/branding/types.d" --> "src/components/branding-provider-utils" { Branding }
    src.lib.auth.client --> "src/app/(admin)/branding/utils" { authFetch }
    "src/app/(admin)/branding/types.d" --> "src/app/(admin)/branding/utils" { BrandingFormResponse }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/DmarcChart" {
        useLanguage,
    }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/DmarcChart" {
        DmarcSeriesDay,
    }
    "src/app/(admin)/deliverability/dmarc-utils" --> "src/app/(admin)/deliverability/DmarcChart" {
        chartMax,
        dayTotal,
        segmentPercents,
    }
    "src/lib/i18n/types.d" --> "src/app/(admin)/deliverability/dmarc-utils" { TranslationKey }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/dmarc-utils" {
        DmarcSeriesDay,
    }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/DmarcRecordPreviewDialog" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/deliverability/DmarcRecordPreviewDialog" {
        Button,
    }
    src.components.ui.dialog --> "src/app/(admin)/deliverability/DmarcRecordPreviewDialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/DmarcRecordPreviewDialog" {
        DmarcPlan,
    }
    "src/app/(admin)/deliverability/dmarc-utils" --> "src/app/(admin)/deliverability/DmarcRecordPreviewDialog" {
        errorKey,
    }
    "src/app/(admin)/deliverability/utils" --> "src/app/(admin)/deliverability/DmarcRecordPreviewDialog" {
        putReports,
    }
    src.lib.auth.client --> "src/app/(admin)/deliverability/utils" { authFetch }
    src.lib.time.utils --> "src/app/(admin)/deliverability/utils" { formatUserDate }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/utils" {
        DeliverabilitySettings,
        DmarcOverview,
        DmarcRange,
        DmarcStats,
        DomainOption,
        MtaStsBody,
        MtaStsOverview,
        MtaStsState,
        ReportsResponse,
        SuppressionMode,
        SuppressionPage,
        TlsOverview,
        TlsRptResponse,
    }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/DmarcTab" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/deliverability/DmarcTab" { Button }
    src.components.ui.checkbox --> "src/app/(admin)/deliverability/DmarcTab" { Checkbox }
    src.components.ui.select --> "src/app/(admin)/deliverability/DmarcTab" { Select }
    "src/app/(admin)/deliverability/DmarcChart" --> "src/app/(admin)/deliverability/DmarcTab" {
        DmarcChart,
    }
    "src/app/(admin)/deliverability/DmarcRecordPreviewDialog" --> "src/app/(admin)/deliverability/DmarcTab" {
        DmarcRecordPreviewDialog,
    }
    "src/app/(admin)/deliverability/DmarcTables" --> "src/app/(admin)/deliverability/DmarcTab" {
        DmarcTables,
    }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/DmarcTab" {
        DmarcOverview,
        DmarcRange,
        DmarcStats,
        OpenAlert,
    }
    "src/app/(admin)/deliverability/dmarc-utils" --> "src/app/(admin)/deliverability/DmarcTab" {
        errorKey,
    }
    "src/app/(admin)/deliverability/utils" --> "src/app/(admin)/deliverability/DmarcTab" {
        acknowledgeAlert,
        fetchDmarc,
        fetchOverview,
        formatEventDate,
        putReports,
    }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/DmarcTables" {
        useLanguage,
    }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/DmarcTables" {
        DmarcRecentReport,
        DmarcStats,
    }
    "src/app/(admin)/deliverability/dmarc-utils" --> "src/app/(admin)/deliverability/DmarcTables" {
        percent,
        reportStatusKey,
    }
    "src/app/(admin)/deliverability/utils" --> "src/app/(admin)/deliverability/DmarcTables" {
        formatEventDate,
    }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/MtaStsDialog" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/deliverability/MtaStsDialog" { Button }
    src.components.ui.checkbox --> "src/app/(admin)/deliverability/MtaStsDialog" { Checkbox }
    src.components.ui.dialog --> "src/app/(admin)/deliverability/MtaStsDialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/MtaStsTab" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/deliverability/MtaStsTab" { Button }
    src.components.ui.select --> "src/app/(admin)/deliverability/MtaStsTab" { Select }
    "src/app/(admin)/deliverability/MtaStsDialog" --> "src/app/(admin)/deliverability/MtaStsTab" {
        MtaStsDialog,
    }
    "src/app/(admin)/deliverability/mta-sts-utils" --> "src/app/(admin)/deliverability/MtaStsTab" {
        MAX_AGE_OPTIONS,
        mtaStsErrorKey,
        mxDiffers,
        policyMatches,
        retiringDays,
    }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/MtaStsTab" {
        MtaStsBody,
        MtaStsOverview,
    }
    "src/app/(admin)/deliverability/utils" --> "src/app/(admin)/deliverability/MtaStsTab" {
        fetchMtaSts,
        formatEventDate,
        postMtaStsVerified,
        putMtaSts,
    }
    "src/lib/i18n/types.d" --> "src/app/(admin)/deliverability/mta-sts-utils" { TranslationKey }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/SettingsPanel" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/deliverability/SettingsPanel" { Button }
    src.components.ui.select --> "src/app/(admin)/deliverability/SettingsPanel" { Select }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/SettingsPanel" {
        DeliverabilitySettings,
        SuppressionMode,
    }
    "src/app/(admin)/deliverability/utils" --> "src/app/(admin)/deliverability/SettingsPanel" {
        fetchSettings,
        saveMode,
        setFeed,
    }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/SuppressionList" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/deliverability/SuppressionList" { Button }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/deliverability/SuppressionList" {
        confirmDestructive,
    }
    src.components.ui.input --> "src/app/(admin)/deliverability/SuppressionList" { Input }
    src.components.ui.select --> "src/app/(admin)/deliverability/SuppressionList" { Select }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/SuppressionList" {
        SuppressionPage,
    }
    "src/app/(admin)/deliverability/utils" --> "src/app/(admin)/deliverability/SuppressionList" {
        PAGE_SIZE,
        confirmSuppression,
        deleteSuppression,
        fetchSuppressions,
        formatEventDate,
    }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/TlsTab" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/deliverability/TlsTab" { Button }
    src.components.ui.select --> "src/app/(admin)/deliverability/TlsTab" { Select }
    "src/app/(admin)/deliverability/DmarcTables" --> "src/app/(admin)/deliverability/TlsTab" {
        RecentReports,
        Table,
        Th,
        headClass,
    }
    "src/app/(admin)/deliverability/mta-sts-utils" --> "src/app/(admin)/deliverability/TlsTab" {
        policyKey,
        tlsErrorKey,
    }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/TlsTab" {
        DmarcRange,
        TlsOverview,
    }
    "src/app/(admin)/deliverability/utils" --> "src/app/(admin)/deliverability/TlsTab" {
        fetchTls,
        putTlsRpt,
    }
    "src/components/language-provider" --> "src/app/(admin)/deliverability/page" { useLanguage }
    src.components.ui.select --> "src/app/(admin)/deliverability/page" { Select }
    "src/app/(admin)/deliverability/DmarcTab" --> "src/app/(admin)/deliverability/page" { DmarcTab }
    "src/app/(admin)/deliverability/MtaStsTab" --> "src/app/(admin)/deliverability/page" {
        MtaStsTab,
    }
    "src/app/(admin)/deliverability/SettingsPanel" --> "src/app/(admin)/deliverability/page" {
        SettingsPanel,
    }
    "src/app/(admin)/deliverability/SuppressionList" --> "src/app/(admin)/deliverability/page" {
        SuppressionList,
    }
    "src/app/(admin)/deliverability/TlsTab" --> "src/app/(admin)/deliverability/page" { TlsTab }
    "src/app/(admin)/deliverability/types.d" --> "src/app/(admin)/deliverability/page" {
        DeliverabilitySettings,
        DomainOption,
    }
    "src/app/(admin)/deliverability/utils" --> "src/app/(admin)/deliverability/page" {
        fetchDomains,
        fetchSettings,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/domains/AwsCredentialsPanel" {
        confirmDestructive,
    }
    "src/components/language-provider" --> "src/app/(admin)/domains/AwsCredentialsPanel" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/domains/AwsCredentialsPanel" { Button }
    src.components.ui.input --> "src/app/(admin)/domains/AwsCredentialsPanel" { Input }
    "src/lib/aws/aws-types.d" --> "src/app/(admin)/domains/AwsCredentialsPanel" {
        AwsCapabilityReport,
        AwsConfigStatus,
    }
    "src/app/(admin)/domains/api" --> "src/app/(admin)/domains/AwsCredentialsPanel" {
        ApiError,
        requestJson,
    }
    "src/app/(admin)/domains/status-row" --> "src/app/(admin)/domains/AwsCredentialsPanel" {
        StatusRow,
    }
    src.lib.i18n.utils --> "src/app/(admin)/domains/api" { defaultTranslator }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/domains/api" { confirmDestructive }
    src.lib.auth.client --> "src/app/(admin)/domains/api" { authFetch }
    src.components.icons --> "src/app/(admin)/domains/status-row" { AlertTriangle, Check }
    "src/components/language-provider" --> "src/app/(admin)/domains/CloudflareReceivingConfig" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/domains/CloudflareReceivingConfig" { Button }
    "src/app/(admin)/domains/api" --> "src/app/(admin)/domains/CloudflareReceivingConfig" {
        runReceivingSetup,
    }
    "src/app/(admin)/domains/status-row" --> "src/app/(admin)/domains/CloudflareReceivingConfig" {
        StatusRow,
    }
    "src/components/language-provider" --> "src/app/(admin)/domains/DomainDnsDetails" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/domains/DomainDnsDetails" { Button }
    "src/app/(admin)/domains/utils" --> "src/app/(admin)/domains/DomainDnsDetails" {
        dnsAuthDescriptions,
        getDnsAuthItemClass,
    }
    "src/app/(admin)/domains/status-row" --> "src/app/(admin)/domains/DomainDnsDetails" {
        ROW_GRID,
        StatusBadge,
        StatusRow,
    }
    "src/app/(admin)/domains/CloudflareReceivingConfig" --> "src/app/(admin)/domains/DomainDnsDetails" {
        default,
    }
    "src/app/(admin)/domains/ReceivingSetupSection" --> "src/app/(admin)/domains/DomainDnsDetails" {
        default,
    }
    "src/app/(admin)/domains/SendingSetupSection" --> "src/app/(admin)/domains/DomainDnsDetails" {
        default,
    }
    "src/app/(admin)/domains/TrackingHostSection" --> "src/app/(admin)/domains/DomainDnsDetails" {
        default,
    }
    "src/app/(admin)/domains/types.d" --> "src/app/(admin)/domains/DomainDnsDetails" {
        DnsAuthRecord,
        DomainDnsDetailsProps,
    }
    "src/lib/i18n/types.d" --> "src/app/(admin)/domains/utils" { TranslationKey }
    src.lib.i18n.utils --> "src/app/(admin)/domains/utils" { Translator, defaultTranslator }
    src.lib.auth.client --> "src/app/(admin)/domains/utils" { authFetch }
    "src/app/(admin)/domains/types.d" --> "src/app/(admin)/domains/utils" {
        DnsAuthRecord,
        DnsAuthStatus,
        DomainPreflightResponse,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/domains/ReceivingSetupSection" {
        confirmDestructive,
    }
    "src/components/language-provider" --> "src/app/(admin)/domains/ReceivingSetupSection" {
        useLanguage,
    }
    "src/lib/i18n/types.d" --> "src/app/(admin)/domains/ReceivingSetupSection" { TranslationKey }
    "src/app/(admin)/domains/api" --> "src/app/(admin)/domains/ReceivingSetupSection" {
        requestJson,
    }
    "src/app/(admin)/domains/ProviderCard" --> "src/app/(admin)/domains/ReceivingSetupSection" {
        default,
    }
    "src/app/(admin)/domains/ReceivingProviderConfig" --> "src/app/(admin)/domains/ReceivingSetupSection" {
        default,
    }
    "src/app/(admin)/domains/types.d" --> "src/app/(admin)/domains/ReceivingSetupSection" {
        Domain,
        ReceivingProvider,
    }
    src.components.icons --> "src/app/(admin)/domains/ProviderCard" { AlertTriangle, Check }
    "src/components/language-provider" --> "src/app/(admin)/domains/ProviderCard" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/domains/ProviderCard" { Button }
    src.components.ui.switch --> "src/app/(admin)/domains/ProviderCard" { Switch }
    "src/components/language-provider" --> "src/app/(admin)/domains/ReceivingProviderConfig" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/domains/ReceivingProviderConfig" { Button }
    "src/lib/aws/ses-receiving-types.d" --> "src/app/(admin)/domains/ReceivingProviderConfig" {
        ReceivingStep,
    }
    "src/app/(admin)/domains/AwsCredentialsPanel" --> "src/app/(admin)/domains/ReceivingProviderConfig" {
        default,
    }
    "src/app/(admin)/domains/ResendKeyRow" --> "src/app/(admin)/domains/ReceivingProviderConfig" {
        default,
    }
    "src/app/(admin)/domains/api" --> "src/app/(admin)/domains/ReceivingProviderConfig" {
        requestJson,
        runReceivingSetup,
    }
    "src/app/(admin)/domains/status-row" --> "src/app/(admin)/domains/ReceivingProviderConfig" {
        StatusRow,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/domains/ResendKeyRow" {
        confirmDestructive,
    }
    "src/components/language-provider" --> "src/app/(admin)/domains/ResendKeyRow" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/domains/ResendKeyRow" { Button }
    src.components.ui.input --> "src/app/(admin)/domains/ResendKeyRow" { Input }
    "src/app/(admin)/domains/api" --> "src/app/(admin)/domains/ResendKeyRow" { postJson }
    "src/app/(admin)/domains/status-row" --> "src/app/(admin)/domains/ResendKeyRow" { StatusRow }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/domains/SendingSetupSection" {
        confirmDestructive,
    }
    "src/components/language-provider" --> "src/app/(admin)/domains/SendingSetupSection" {
        useLanguage,
    }
    "src/lib/i18n/types.d" --> "src/app/(admin)/domains/SendingSetupSection" { TranslationKey }
    "src/app/(admin)/domains/api" --> "src/app/(admin)/domains/SendingSetupSection" { requestJson }
    "src/app/(admin)/domains/ProviderCard" --> "src/app/(admin)/domains/SendingSetupSection" {
        default,
    }
    "src/app/(admin)/domains/ResendDomainSection" --> "src/app/(admin)/domains/SendingSetupSection" {
        default,
    }
    "src/app/(admin)/domains/SesSendingConfig" --> "src/app/(admin)/domains/SendingSetupSection" {
        default,
    }
    "src/app/(admin)/domains/types.d" --> "src/app/(admin)/domains/SendingSetupSection" {
        Domain,
        SendingProvider,
    }
    src.components.ui.button --> "src/app/(admin)/domains/ResendDomainSection" { Button }
    "src/components/language-provider" --> "src/app/(admin)/domains/ResendDomainSection" {
        useLanguage,
    }
    src.lib.auth.client --> "src/app/(admin)/domains/ResendDomainSection" { authFetch }
    "src/lib/domains/resend-domain-types.d" --> "src/app/(admin)/domains/ResendDomainSection" {
        ResendDomainView,
    }
    "src/app/(admin)/domains/ResendKeyRow" --> "src/app/(admin)/domains/ResendDomainSection" {
        default,
    }
    "src/app/(admin)/domains/status-row" --> "src/app/(admin)/domains/ResendDomainSection" {
        StatusRow,
    }
    "src/components/language-provider" --> "src/app/(admin)/domains/SesSendingConfig" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/domains/SesSendingConfig" { Button }
    "src/lib/aws/ses-sending-types.d" --> "src/app/(admin)/domains/SesSendingConfig" {
        SesSendingView,
    }
    "src/app/(admin)/domains/AwsCredentialsPanel" --> "src/app/(admin)/domains/SesSendingConfig" {
        default,
    }
    "src/app/(admin)/domains/api" --> "src/app/(admin)/domains/SesSendingConfig" { requestJson }
    "src/app/(admin)/domains/status-row" --> "src/app/(admin)/domains/SesSendingConfig" {
        StatusRow,
    }
    "src/components/language-provider" --> "src/app/(admin)/domains/TrackingHostSection" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(admin)/domains/TrackingHostSection" { Button }
    src.components.ui.input --> "src/app/(admin)/domains/TrackingHostSection" { Input }
    "src/app/(admin)/domains/api" --> "src/app/(admin)/domains/TrackingHostSection" { requestJson }
    "src/app/(admin)/domains/status-row" --> "src/app/(admin)/domains/TrackingHostSection" {
        ROW_GRID,
        StatusBadge,
    }
    "src/app/(admin)/domains/tracking-host-utils" --> "src/app/(admin)/domains/TrackingHostSection" {
        probeTrackingHost,
    }
    "src/app/(admin)/domains/types.d" --> "src/app/(admin)/domains/TrackingHostSection" { Domain }
    src.components.ui.skeleton --> "src/app/(admin)/domains/DomainDnsSkeleton" { Skeleton }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/domains/DomainItemCard" {
        confirmDestructive,
    }
    "src/components/language-provider" --> "src/app/(admin)/domains/DomainItemCard" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/domains/DomainItemCard" { Button }
    src.components.ui.badge --> "src/app/(admin)/domains/DomainItemCard" { Badge }
    src.components.ui.list --> "src/app/(admin)/domains/DomainItemCard" { ListRow }
    src.lib.utils --> "src/app/(admin)/domains/DomainItemCard" { cn }
    "src/app/(admin)/domains/DomainDnsDetails" --> "src/app/(admin)/domains/DomainItemCard" {
        default,
    }
    "src/app/(admin)/domains/DomainDnsSkeleton" --> "src/app/(admin)/domains/DomainItemCard" {
        default,
    }
    "src/app/(admin)/domains/utils" --> "src/app/(admin)/domains/DomainItemCard" {
        dnsAuthRecords,
        getDnsAuthStatusLabel,
    }
    src.components.icons --> "src/app/(admin)/domains/DomainItemCard" {
        AlertTriangle,
        Check,
        ChevronDown,
        ChevronRight,
        Globe2,
        MoreVertical,
        Trash2,
    }
    "src/app/(admin)/domains/types.d" --> "src/app/(admin)/domains/DomainItemCard" {
        DomainItemCardProps,
    }
    "src/app/(admin)/domains/types.d" --> "src/app/(admin)/domains/domain-dns-details-utils" {
        DnsRecord,
    }
    "src/components/page-header-utils" --> "src/app/(admin)/domains/page" {
        mobilePrimaryActionClass,
    }
    "src/components/language-provider" --> "src/app/(admin)/domains/page" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/domains/page" { Button }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/domains/page" {
        alertDialog,
        confirmDestructive,
    }
    src.components.ui.dialog --> "src/app/(admin)/domains/page" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
        DialogTrigger,
    }
    src.components.ui.input --> "src/app/(admin)/domains/page" { Input }
    src.components.ui.label --> "src/app/(admin)/domains/page" { Label }
    src.components.ui.switch --> "src/app/(admin)/domains/page" { Switch }
    src.components.ui.list --> "src/app/(admin)/domains/page" { List }
    src.components.icons --> "src/app/(admin)/domains/page" { CheckCircle2, LoaderCircle, Plus }
    src.lib.auth.client --> "src/app/(admin)/domains/page" { authFetch }
    "src/app/(admin)/domains/types.d" --> "src/app/(admin)/domains/page" {
        DnsAuthRecord,
        DnsStatusSummary,
        Domain,
        DomainDnsCache,
        DomainDnsView,
        DomainPreflight,
        ReceivingProvider,
        SendingProvider,
    }
    "src/app/(admin)/domains/DomainItemCard" --> "src/app/(admin)/domains/page" { default }
    "src/components/page-skeletons" --> "src/app/(admin)/domains/page" { SectionRowSkeleton }
    "src/app/(admin)/domains/utils" --> "src/app/(admin)/domains/page" { checkDomain }
    "src/app/(admin)/domains/api" --> "src/app/(admin)/domains/page" {
        confirmMxReplacement,
        createDomain,
        isMxConflictError,
    }
    src.components.ui.select --> "src/app/(admin)/domains/page" { Select }
    "src/components/language-provider" --> "src/app/(admin)/general/page" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/general/page" { Button }
    src.components.ui.card --> "src/app/(admin)/general/page" {
        Card,
        CardContent,
        CardHeader,
        CardTitle,
    }
    src.components.ui.input --> "src/app/(admin)/general/page" { Input }
    src.components.ui.label --> "src/app/(admin)/general/page" { Label }
    src.components.ui.switch --> "src/app/(admin)/general/page" { Switch }
    "src/app/(admin)/general/utils" --> "src/app/(admin)/general/page" {
        loadGeneralSettings,
        saveGeneralSettings,
    }
    src.lib.auth.client --> "src/app/(admin)/general/utils" { authFetch }
    "src/app/(admin)/general/types.d" --> "src/app/(admin)/general/utils" { GeneralSettings }
    "src/components/skip-to-content" --> "src/app/(admin)/layout" { SkipToContent }
    src.components.icons --> "src/app/(admin)/layout" { HelpCircle, Search }
    "src/components/language-provider" --> "src/app/(admin)/layout" { useLanguage }
    "src/components/auth/auth-guard" --> "src/app/(admin)/layout" { AuthGuard }
    "src/components/compose/compose-context" --> "src/app/(admin)/layout" { ComposeProvider }
    "src/components/compose/floating-composer" --> "src/app/(admin)/layout" { FloatingComposer }
    "src/components/mail-search/mail-search-context" --> "src/app/(admin)/layout" {
        MailSearchProvider,
    }
    "src/components/mailbox-provider" --> "src/app/(admin)/layout" { MailboxProvider }
    "src/components/mailbox-selector" --> "src/app/(admin)/layout" { MailboxSelector }
    "src/components/license-indicator" --> "src/app/(admin)/layout" { LicenseIndicator }
    "src/components/admin-nav" --> "src/app/(admin)/layout" { AdminNav }
    "src/components/sidebar-state" --> "src/app/(admin)/layout" { SidebarProvider }
    "src/components/admin-page-titles" --> "src/app/(admin)/layout" { adminPageTitles }
    "src/components/sidebar-aside" --> "src/app/(admin)/layout" { MobileTopBar, SidebarAside }
    "src/components/sidebar-resize-boundary" --> "src/app/(admin)/layout" { SidebarResizeBoundary }
    src.components.shortcuts.index --> "src/app/(admin)/layout" { ShortcutsProvider }
    "src/components/route-title" --> "src/app/(admin)/layout" { RouteTitle }
    "src/components/language-provider" --> "src/components/skip-to-content" { useLanguage }
    "src/hooks/use-current-user" --> "src/components/auth/auth-guard" {
        fetchSessionInfo,
        peekSessionInfo,
    }
    "src/components/auth/auth-guard-types.d" --> "src/components/auth/auth-guard" { AuthGuardProps }
    "src/components/loading-transition" --> "src/components/auth/auth-guard" { LoadingTransition }
    src.lib.time.client --> "src/components/auth/auth-guard" { saveUserTimeZonePreference }
    "src/components/language-provider" --> "src/components/loading-transition" { useLanguage }
    "src/components/page-loading" --> "src/components/loading-transition" { PageLoadingContext }
    "src/components/route-loading-bar" --> "src/components/loading-transition" { RouteLoadingBar }
    "src/components/route-skeleton" --> "src/components/loading-transition" { RouteSkeleton }
    "src/components/loading-transition-types.d" --> "src/components/loading-transition" {
        LoadingTransitionProps,
    }
    "src/components/loading-transition-types.d" --> "src/components/page-loading" {
        PageLoadingContextValue,
    }
    src.components.ui.skeleton --> "src/components/route-skeleton" { Skeleton, SkeletonRows }
    "src/components/compose/send-notice-utils" --> "src/components/compose/compose-context" {
        SendNoticeParts,
    }
    src.components.icons --> "src/components/compose/floating-composer" { Loader2, MailPlus }
    "src/components/compose/compose-form" --> "src/components/compose/floating-composer" {
        ComposeForm,
    }
    "src/components/compose/compose-context" --> "src/components/compose/floating-composer" {
        ComposeNotice,
        ComposeNoticeAction,
        useCompose,
    }
    "src/components/sidebar-state" --> "src/components/compose/floating-composer" { useSidebar }
    "src/components/language-provider" --> "src/components/compose/floating-composer" {
        useLanguage,
    }
    src.lib.auth.client --> "src/components/compose/floating-composer" { authFetch }
    src.lib.utils --> "src/components/compose/floating-composer" { cn }
    src.components.icons --> "src/components/compose/compose-form" {
        BellRing,
        ChevronUp,
        Eye,
        EyeOff,
        FileText,
        Forward,
        Maximize2,
        Minimize2,
        Minus,
        Paperclip,
        Reply,
        Trash2,
        X,
    }
    "src/components/language-provider" --> "src/components/compose/compose-form" { useLanguage }
    src.components.ui.button --> "src/components/compose/compose-form" { Button }
    src.components.ui.input --> "src/components/compose/compose-form" { Input }
    src.components.ui.label --> "src/components/compose/compose-form" { Label }
    src.components.ui.select --> "src/components/compose/compose-form" { Select }
    src.components.ui.tooltip --> "src/components/compose/compose-form" { Tooltip }
    "src/components/mailbox-provider" --> "src/components/compose/compose-form" {
        useSelectedMailbox,
    }
    src.lib.auth.client --> "src/components/compose/compose-form" { authFetch }
    src.lib.email.address --> "src/components/compose/compose-form" {
        formatEmailAddress,
        getEmailAddress,
    }
    "src/lib/messages/detail-cache" --> "src/components/compose/compose-form" {
        clearMessageDetailCache,
    }
    "src/components/compose/compose-context" --> "src/components/compose/compose-form" {
        useCompose,
    }
    src.lib.utils --> "src/components/compose/compose-form" { cn }
    "src/components/agent/send-review" --> "src/components/compose/compose-form" { SendReview }
    "src/components/agent/send-review-types.d" --> "src/components/compose/compose-form" {
        ReviewSnapshot,
    }
    "src/components/sidebar-mobile-utils" --> "src/components/compose/compose-form" { useIsMobile }
    "src/components/compose/use-sheet-viewport" --> "src/components/compose/compose-form" {
        useSheetViewport,
    }
    "src/components/compose/use-track-opens" --> "src/components/compose/compose-form" {
        useTrackOpens,
    }
    "src/components/follow-ups/follow-up-menu" --> "src/components/compose/compose-form" {
        FollowUpMenu,
    }
    "src/components/follow-ups/follow-up-client-utils" --> "src/components/compose/compose-form" {
        followUpOptionKey,
    }
    "src/components/messages/scheduled-send-utils" --> "src/components/compose/compose-form" {
        formatScheduledSendTime,
    }
    src.components.compose.utils --> "src/components/compose/compose-form" {
        buildSendFormData,
        fetchDraft,
        formatAttachmentSize,
    }
    "src/components/compose/recipient-input" --> "src/components/compose/compose-form" {
        RecipientInput,
    }
    "src/components/compose/rich-text-editor" --> "src/components/compose/compose-form" {
        RichTextEditor,
    }
    "src/components/compose/schedule-send-menu" --> "src/components/compose/compose-form" {
        ScheduleSendMenu,
    }
    "src/components/compose/schedule-send-utils" --> "src/components/compose/compose-form" {
        isPastSchedule,
    }
    "src/components/compose/send-notice-utils" --> "src/components/compose/compose-form" {
        DELIVERY_WAIT_MS,
        SCHEDULED_NOTICE_MS,
        SENT_NOTICE_MS,
        SendNoticeParts,
        SendResult,
        resolveSendNotice,
        splitSendTemplate,
    }
    "src/components/compose/rich-text-utils" --> "src/components/compose/compose-form" {
        applyMailboxSignatureHtml,
        hasMeaningfulHtml,
        htmlToPlainText,
        joinQuotedHtml,
        splitQuotedHtml,
        textToHtml,
    }
    "src/components/compose/recipient-utils" --> "src/components/compose/compose-form" {
        headerToRecipients,
        isValidRecipient,
        mergeRecipients,
        recipientsToHeader,
    }
    "src/components/compose/types.d" --> "src/components/compose/compose-form" {
        ComposeAttachment,
        ComposeStoredAttachment,
        ComposeThreading,
    }
    "src/components/compose/attachment-policy-types.d" --> "src/components/compose/compose-form" {
        ComposeAttachmentPolicy,
    }
    src.lib.utils --> src.components.ui.tooltip { cn }
    "src/components/ui/tooltip-types.d" --> src.components.ui.tooltip {
        TooltipPosition,
        TooltipProps,
    }
    "src/components/ui/tooltip-utils" --> src.components.ui.tooltip { getTooltipPosition }
    "src/components/ui/tooltip-types.d" --> "src/components/ui/tooltip-utils" {
        TooltipPosition,
        TooltipProps,
    }
    src.lib.auth.client --> "src/lib/messages/detail-cache" {
        AUTH_SESSION_CHANGED_EVENT,
        authFetch,
    }
    "src/lib/messages/field-store" --> "src/lib/messages/detail-cache" {
        applyPendingToMessage,
        rememberMessageFields,
    }
    "src/hooks/types.d" --> "src/lib/messages/detail-cache" { Message }
    "src/lib/messages/detail-cache-types.d" --> "src/lib/messages/detail-cache" {
        CachedMessageDetail,
    }
    "src/components/language-provider" --> "src/components/agent/send-review" { useLanguage }
    src.lib.auth.client --> "src/components/agent/send-review" { authFetch }
    src.lib.time.utils --> "src/components/agent/send-review" { formatUserDate }
    "src/components/use-dialog-focus" --> "src/components/agent/send-review" { useDialogFocus }
    "src/components/compose/rich-text-utils" --> "src/components/agent/send-review" {
        htmlToPlainText,
    }
    "src/components/agent/send-review-types.d" --> "src/components/agent/send-review" {
        SendReviewProps,
    }
    "src/components/compose/sheet-viewport-utils" --> "src/components/compose/use-sheet-viewport" {
        getSheetViewportStyle,
    }
    "src/components/compose/compose-preferences-utils" --> "src/components/compose/use-track-opens" {
        getCachedComposePreferences,
        loadComposePreferences,
    }
    src.lib.auth.client --> "src/components/compose/compose-preferences-utils" { authFetch }
    "src/lib/compose/types.d" --> "src/components/compose/compose-preferences-utils" {
        ComposePreferences,
    }
    src.components.icons --> "src/components/follow-ups/follow-up-menu" { X }
    "src/components/language-provider" --> "src/components/follow-ups/follow-up-menu" {
        useLanguage,
    }
    "src/lib/follow-ups/follow-up-utils" --> "src/components/follow-ups/follow-up-menu" {
        FOLLOW_UP_DAY_OPTIONS,
    }
    "src/components/follow-ups/follow-up-client-utils" --> "src/components/follow-ups/follow-up-menu" {
        followUpOptionKey,
    }
    src.lib.auth.client --> "src/components/follow-ups/follow-up-client-utils" { authFetch }
    "src/lib/follow-ups/types.d" --> "src/components/follow-ups/follow-up-client-utils" {
        DueFollowUp,
        MessageFollowUp,
    }
    "src/lib/i18n/types.d" --> "src/components/follow-ups/follow-up-client-utils" { TranslationKey }
    src.lib.time.utils --> "src/components/messages/scheduled-send-utils" {
        formatUserDate,
        getUserTimeZone,
        zonedDateFields,
    }
    src.lib.i18n.utils --> "src/components/messages/scheduled-send-utils" { Translator }
    src.lib.auth.client --> src.components.compose.utils { authFetch }
    "src/components/compose/types.d" --> src.components.compose.utils {
        ComposeAttachment,
        ComposeDraft,
        ComposeThreading,
        DraftResponse,
    }
    src.components.icons --> "src/components/compose/recipient-input" { X }
    "src/components/language-provider" --> "src/components/compose/recipient-input" { useLanguage }
    src.components.ui.label --> "src/components/compose/recipient-input" { Label }
    src.lib.email.address --> "src/components/compose/recipient-input" { getEmailAddress }
    src.lib.utils --> "src/components/compose/recipient-input" { cn }
    "src/components/compose/recipient-input-types.d" --> "src/components/compose/recipient-input" {
        RecipientInputProps,
    }
    "src/components/compose/recipient-suggestions-types.d" --> "src/components/compose/recipient-input" {
        ContactSuggestion,
    }
    "src/components/compose/recipient-suggestions" --> "src/components/compose/recipient-input" {
        RecipientSuggestions,
    }
    "src/components/compose/recipient-suggestions-utils" --> "src/components/compose/recipient-input" {
        fetchContactSuggestions,
        filterContactSuggestions,
        formatContactSuggestion,
    }
    "src/components/compose/recipient-utils" --> "src/components/compose/recipient-input" {
        getRecipientLabel,
        isValidRecipient,
        parseRecipientEntries,
    }
    "src/components/contacts/contact-avatar" --> "src/components/compose/recipient-suggestions" {
        ContactAvatar,
    }
    src.lib.utils --> "src/components/compose/recipient-suggestions" { cn }
    "src/components/compose/recipient-suggestions-types.d" --> "src/components/compose/recipient-suggestions" {
        RecipientSuggestionsProps,
    }
    "src/components/progressive-avatar-image" --> "src/components/contacts/contact-avatar" {
        ProgressiveAvatarImage,
    }
    "src/lib/contacts/avatar-client" --> "src/components/contacts/contact-avatar" {
        CONTACT_AVATAR_CHANGED_EVENT,
    }
    src.lib.email.address --> "src/components/contacts/contact-avatar" { normalizeEmailAddress }
    "src/lib/avatar-colors" --> "src/components/contacts/contact-avatar" { getAvatarColorStyle }
    src.lib.utils --> "src/components/contacts/contact-avatar" { cn }
    "src/components/contacts/contact-avatar-types.d" --> "src/components/contacts/contact-avatar" {
        ContactAvatarProps,
    }
    "src/components/contacts/contact-avatar-utils" --> "src/components/contacts/contact-avatar" {
        getContactAvatarInitial,
        getManagedContactAvatarUrl,
    }
    "src/lib/contacts/avatar-client-types.d" --> "src/lib/contacts/avatar-client" {
        ContactAvatarChangedDetail,
    }
    src.lib.email.address --> "src/components/contacts/contact-avatar-utils" { getEmailAddress }
    src.lib.auth.client --> "src/components/compose/recipient-suggestions-utils" { authFetch }
    src.lib.email.address --> "src/components/compose/recipient-suggestions-utils" {
        formatEmailAddress,
        getEmailAddress,
    }
    "src/components/compose/recipient-suggestions-types.d" --> "src/components/compose/recipient-suggestions-utils" {
        ContactSuggestion,
        ContactSuggestionsResponse,
    }
    src.lib.email.address --> "src/components/compose/recipient-utils" {
        getEmailAddress,
        joinEmailAddressList,
        parseEmailAddressParts,
        splitEmailAddressList,
    }
    src.components.icons --> "src/components/compose/rich-text-editor" {
        Bold,
        Italic,
        Link2,
        List,
        ListOrdered,
        Quote,
        RemoveFormatting,
        Strikethrough,
        Underline,
    }
    "src/components/language-provider" --> "src/components/compose/rich-text-editor" { useLanguage }
    src.components.ui.tooltip --> "src/components/compose/rich-text-editor" { Tooltip }
    src.lib.utils --> "src/components/compose/rich-text-editor" { cn }
    "src/components/messages/email-html-renderer" --> "src/components/compose/rich-text-editor" {
        EmailHtmlRenderer,
    }
    src.lib.email.html --> "src/components/compose/rich-text-editor" {
        sanitizeEditorHtml,
        sanitizeEmailHtml,
    }
    "src/components/compose/rich-text-editor-types.d" --> "src/components/compose/rich-text-editor" {
        RichTextEditorProps,
        ToolbarCommand,
    }
    "src/components/language-provider" --> "src/components/messages/email-html-renderer" {
        useLanguage,
    }
    "src/lib/remote-images/reader" --> "src/components/messages/email-html-renderer" {
        prepareReaderEmailHtml,
    }
    "src/app/(dashboard)/inbox/[messageId]/quote-collapse-utils" --> "src/components/messages/email-html-renderer" {
        collapseQuotedEmailHtml,
    }
    src.lib.email.html --> "src/lib/remote-images/reader" { prepareEmailHtml }
    src.components.icons --> "src/components/compose/schedule-send-menu" { ChevronDown, X }
    "src/components/language-provider" --> "src/components/compose/schedule-send-menu" {
        useLanguage,
    }
    "src/components/compose/new-template-dialog" --> "src/components/compose/schedule-send-menu" {
        NewTemplateDialog,
    }
    "src/components/compose/template-menu" --> "src/components/compose/schedule-send-menu" {
        TemplateMenu,
    }
    "src/components/compose/schedule-send-utils" --> "src/components/compose/schedule-send-menu" {
        formatDateTimeLocal,
        formatScheduledSend,
        getScheduleSendOptions,
        isPastSchedule,
        parseDateTimeLocal,
    }
    "src/components/compose/schedule-send-types.d" --> "src/components/compose/schedule-send-menu" {
        ScheduleSendMenuProps,
    }
    "src/components/sidebar-mobile-utils" --> "src/components/compose/schedule-send-menu" {
        useIsMobile,
    }
    "src/components/compose/schedule-send-sheet" --> "src/components/compose/schedule-send-menu" {
        ScheduleSendSheet,
    }
    src.lib.time.utils --> "src/components/compose/schedule-send-menu" { getUserTimeZone }
    "src/components/language-provider" --> "src/components/compose/new-template-dialog" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/compose/new-template-dialog" { Button }
    src.components.ui.dialog --> "src/components/compose/new-template-dialog" {
        Dialog,
        DialogContent,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/compose/new-template-dialog" { Input }
    src.components.ui.label --> "src/components/compose/new-template-dialog" { Label }
    src.components.ui.textarea --> "src/components/compose/new-template-dialog" { Textarea }
    src.lib.auth.client --> "src/components/compose/new-template-dialog" { authFetch }
    "src/components/compose/rich-text-utils" --> "src/components/compose/new-template-dialog" {
        textToHtml,
    }
    "src/components/compose/template-types.d" --> "src/components/compose/new-template-dialog" {
        NewTemplateDialogProps,
    }
    src.lib.utils --> src.components.ui.textarea { cn }
    src.components.icons --> "src/components/compose/template-menu" {
        ChevronRight,
        FileText,
        Plus,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/compose/template-menu" { useLanguage }
    src.lib.auth.client --> "src/components/compose/template-menu" { authFetch }
    "src/components/compose/rich-text-utils" --> "src/components/compose/template-menu" {
        textToHtml,
    }
    "src/components/compose/template-types.d" --> "src/components/compose/template-menu" {
        ComposeTemplate,
        TemplateMenuProps,
    }
    "src/components/compose/schedule-send-types.d" --> "src/components/compose/schedule-send-utils" {
        ScheduleSendOption,
    }
    src.lib.time.utils --> "src/components/compose/schedule-send-utils" {
        dateFromZonedFields,
        formatUserDate,
        formatUserDateTimeLocal,
        getUserTimeZone,
        parseUserDateTimeLocal,
        zonedDateFields,
    }
    src.components.icons --> "src/components/compose/schedule-send-sheet" {
        CalendarClock,
        ChevronLeft,
        ChevronRight,
        FileText,
        Plus,
        X,
    }
    src.components.ui.button --> "src/components/compose/schedule-send-sheet" { Button }
    "src/components/language-provider" --> "src/components/compose/schedule-send-sheet" {
        useLanguage,
    }
    src.lib.auth.client --> "src/components/compose/schedule-send-sheet" { authFetch }
    src.lib.utils --> "src/components/compose/schedule-send-sheet" { cn }
    src.lib.time.utils --> "src/components/compose/schedule-send-sheet" { getUserTimeZone }
    "src/components/compose/rich-text-utils" --> "src/components/compose/schedule-send-sheet" {
        textToHtml,
    }
    "src/components/compose/schedule-send-utils" --> "src/components/compose/schedule-send-sheet" {
        formatDateTimeLocal,
        formatScheduledSend,
        getScheduleSendOptions,
        isPastSchedule,
        parseDateTimeLocal,
    }
    "src/components/compose/schedule-send-types.d" --> "src/components/compose/schedule-send-sheet" {
        ScheduleSendSheetProps,
    }
    "src/components/compose/template-types.d" --> "src/components/compose/schedule-send-sheet" {
        ComposeTemplate,
    }
    "src/hooks/use-current-user" --> "src/components/sidebar-state" { fetchCurrentUser }
    "src/components/column-width-preferences" --> "src/components/sidebar-state" {
        readColumnWidth,
        readInitialColumnWidth,
        saveColumnWidth,
    }
    "src/components/sidebar-mobile-utils" --> "src/components/sidebar-state" {
        isMobileViewport,
        useIsMobile,
    }
    "src/components/sidebar-state-utils" --> "src/components/sidebar-state" {
        readInitialSidebarMinimal,
        saveInitialSidebarMinimal,
        syncInitialSidebarWidth,
    }
    "src/components/sidebar-state-types.d" --> "src/components/sidebar-state" {
        SidebarProviderProps,
        SidebarState,
    }
    "src/components/column-width-preferences-types.d" --> "src/components/column-width-preferences" {
        ColumnWidthPreference,
    }
    "src/components/mail-search/types.d" --> "src/components/mail-search/mail-search-context" {
        MailSearchContextValue,
    }
    "src/components/ui/confirm-dialog" --> "src/components/mailbox-selector" {
        alertDialog,
        confirmDestructive,
    }
    src.components.icons --> "src/components/mailbox-selector" {
        Check,
        ChevronDown,
        LogOut,
        Settings,
        ShieldCheck,
        UserPlus,
        UserRound,
        UsersRound,
    }
    "src/components/use-dismissible" --> "src/components/mailbox-selector" { useDismissible }
    "src/components/apps-menu" --> "src/components/mailbox-selector" { AppsMenu }
    "src/components/language-provider" --> "src/components/mailbox-selector" { useLanguage }
    "src/components/mailbox-provider" --> "src/components/mailbox-selector" { useSelectedMailbox }
    "src/components/progressive-avatar-image" --> "src/components/mailbox-selector" {
        ProgressiveAvatarImage,
    }
    "src/components/mailbox-provider-utils" --> "src/components/mailbox-selector" {
        isIdentityMailbox,
    }
    "src/hooks/use-message-counts" --> "src/components/mailbox-selector" { useMessageCounts }
    "src/hooks/use-current-user" --> "src/components/mailbox-selector" {
        clearCurrentUserCache,
        fetchCurrentUser,
    }
    "src/lib/avatar-colors" --> "src/components/mailbox-selector" { getAvatarColorStyle }
    src.lib.auth.logout --> "src/components/mailbox-selector" { logoutClientSession }
    "src/lib/auth/accounts-client" --> "src/components/mailbox-selector" {
        BrowserAccount,
        fetchBrowserAccounts,
        signOutBrowserAccount,
        switchBrowserAccount,
    }
    "src/lib/profile/avatar-client" --> "src/components/mailbox-selector" {
        PROFILE_AVATAR_CHANGED_EVENT,
        getProfileAvatarUrl,
    }
    "src/lib/profile/name-client" --> "src/components/mailbox-selector" {
        PROFILE_NAME_CHANGED_EVENT,
    }
    "src/lib/profile/types.d" --> "src/components/mailbox-selector" {
        ProfileAvatarChangedDetail,
        ProfileNameChangedDetail,
    }
    "src/lib/mailboxes/avatar-client" --> "src/components/mailbox-selector" {
        MAILBOX_AVATAR_CHANGED_EVENT,
    }
    "src/lib/mailboxes/avatar-client-types.d" --> "src/components/mailbox-selector" {
        MailboxAvatarChangedDetail,
    }
    src.components.ui.skeleton --> "src/components/mailbox-selector" { Skeleton }
    src.components.ui.tooltip --> "src/components/mailbox-selector" { Tooltip }
    "src/components/mailbox-selector-types.d" --> "src/components/mailbox-selector" {
        AccountAvatarProps,
        MailboxAccountRowProps,
        MailboxSelectorProps,
        MailboxSelectorUser,
    }
    "src/components/mailbox-selector-utils" --> "src/components/mailbox-selector" {
        getAccountInitial,
        getMailboxAddress,
        getMailboxName,
        isAdminPath,
    }
    src.components.icons --> "src/components/apps-menu" {
        CalendarDays,
        HardDrive,
        Inbox,
        More01,
        UsersRound,
    }
    "src/components/language-provider" --> "src/components/apps-menu" { useLanguage }
    "src/components/use-dismissible" --> "src/components/apps-menu" { useDismissible }
    "src/components/mailbox-selector-types.d" --> "src/components/apps-menu" { AppsMenuProps }
    "src/hooks/types.d" --> "src/hooks/use-message-counts" { MessageCounts, MessageCountsDelta }
    "src/lib/messages/field-store" --> "src/hooks/use-message-counts" {
        hasPendingOverlay,
        subscribePendingOverlay,
    }
    "src/hooks/message-refresh" --> "src/hooks/use-message-counts" { registerMessageRefresh }
    "src/lib/messages/membership-store" --> "src/hooks/use-message-counts" {
        hasMembershipOverlay,
        subscribeMembership,
    }
    "src/hooks/counts-delta-utils" --> "src/hooks/use-message-counts" { applyCountsDelta }
    src.hooks.utils --> "src/hooks/use-message-counts" {
        clearMessageCountsCache,
        fetchMessageCounts,
    }
    src.hooks.utils --> "src/hooks/message-refresh" {
        clearMessageCountsCache,
        clearMessageListCache,
    }
    src.lib.auth.client --> src.hooks.utils { authFetch }
    "src/lib/search/query-utils" --> src.hooks.utils { parseSearchQuery }
    src.lib.time.utils --> src.hooks.utils { getUserTimeZone }
    "src/lib/messages/detail-cache" --> src.hooks.utils { patchCachedMessage }
    "src/lib/messages/field-store" --> src.hooks.utils {
        ThreadUnreadTarget,
        applyPendingToMessageList,
        applyPendingToMessages,
        getThreadUnreadTargets,
        rememberMessageRows,
    }
    "src/lib/messages/membership-store" --> src.hooks.utils {
        applyMembershipToList,
        clearMembershipState,
        rememberMembershipRows,
    }
    "src/lib/messages/change-events" --> src.hooks.utils { MessageFieldPatch, isReadOnlyChange }
    "src/hooks/types.d" --> src.hooks.utils {
        MessageCounts,
        MessageFilterOptions,
        MessageFolder,
        MessageListResponse,
    }
    "src/hooks/types.d" --> "src/lib/messages/membership-store" { Message }
    "src/lib/messages/change-events" --> "src/lib/messages/membership-store" {
        MessageMembershipState,
    }
    "src/lib/messages/list-membership" --> "src/lib/messages/membership-store" {
        MessageMembershipFields,
        getListMembershipContext,
        getListMembershipKey,
        messageMatchesFolder,
    }
    "src/lib/messages/field-store" --> "src/lib/messages/change-events" { ThreadUnreadTarget }
    "src/lib/messages/list-membership" --> "src/lib/messages/change-events" {
        MessageMembershipFields,
    }
    "src/lib/messages/actions/types.d" --> "src/lib/messages/change-events" {
        ReversibleMessageAction,
    }
    "src/hooks/types.d" --> "src/lib/messages/list-membership" { MessageFolder }
    "src/lib/messages/actions/types.d" --> "src/lib/messages/list-membership" {
        MessageStateSnapshot,
    }
    "src/hooks/types.d" --> "src/hooks/counts-delta-utils" { MessageCounts, MessageCountsDelta }
    src.lib.auth.client --> src.lib.auth.logout {
        authFetch,
        clearClientSessionToken,
        setClientSessionToken,
    }
    "src/lib/push/app-badge" --> src.lib.auth.logout { setAppBadgeCount }
    src.lib.auth.client --> "src/lib/auth/accounts-client" { authFetch, setClientSessionToken }
    "src/lib/mailboxes/avatar-client-types.d" --> "src/lib/mailboxes/avatar-client" {
        MailboxAvatarChangedDetail,
    }
    "src/components/mailbox-provider" --> "src/components/mailbox-selector-utils" { MailboxOption }
    "src/components/language-provider" --> "src/components/license-indicator" { useLanguage }
    src.components.ui.button --> "src/components/license-indicator" { Button }
    "src/lib/licenses/types.d" --> "src/components/license-indicator" { LicenseStatus }
    "src/components/license-indicator-utils" --> "src/components/license-indicator" {
        loadLicenseIndicatorStatus,
    }
    src.lib.licenses.constants --> "src/components/license-indicator" {
        LICENSE_STATUS_CHANGED_EVENT,
    }
    src.lib.auth.client --> "src/components/license-indicator-utils" { authFetch }
    "src/components/license-indicator-types.d" --> "src/components/license-indicator-utils" {
        LicenseIndicatorResponse,
    }
    src.components.icons --> "src/components/admin-nav" {
        Activity,
        BadgeDollarSign,
        Bot,
        DatabaseBackup,
        Globe2,
        KeyRound,
        Mail,
        Palette,
        Route,
        Settings,
        ShieldAlert,
        ShieldCheck,
        Users,
        Webhook,
    }
    src.lib.utils --> "src/components/admin-nav" { cn }
    "src/components/language-provider" --> "src/components/admin-nav" { useLanguage }
    "src/lib/i18n/types.d" --> "src/components/admin-nav" { TranslationKey }
    "src/components/components-nav-types.d" --> "src/components/admin-nav" { NavLink }
    "src/hooks/use-current-user" --> "src/components/admin-nav" { useCurrentUser }
    "src/components/components-nav" --> "src/components/admin-nav" { NavItem }
    "src/components/nav-section-header" --> "src/components/admin-nav" {
        NavSectionHeader,
        useSectionOpen,
    }
    "src/components/sidebar-footer" --> "src/components/admin-nav" { SidebarFooter }
    "src/components/sidebar-header" --> "src/components/admin-nav" { SidebarHeader }
    "src/components/sidebar-scaffold" --> "src/components/admin-nav" { SidebarScaffold }
    "src/components/sidebar-state" --> "src/components/admin-nav" { useSidebar }
    src.lib.utils --> "src/components/components-nav" { cn }
    "src/lib/messages/drag-utils" --> "src/components/components-nav" { getMessageDragData }
    "src/components/mail-search/mail-search-context" --> "src/components/components-nav" {
        useMailSearch,
    }
    "src/components/messages/use-conversation-view" --> "src/components/components-nav" {
        useConversationView,
    }
    "src/components/mailbox-provider" --> "src/components/components-nav" { useSelectedMailbox }
    "src/components/sidebar-state" --> "src/components/components-nav" { useSidebar }
    "src/components/compose/compose-context" --> "src/components/components-nav" { useCompose }
    src.components.ui.tooltip --> "src/components/components-nav" { Tooltip }
    src.lib.navigation.prefetch --> "src/components/components-nav" { FULL_ROUTE_PREFETCH }
    "src/components/components-nav-utils" --> "src/components/components-nav" { preloadMailboxPage }
    "src/components/components-nav-types.d" --> "src/components/components-nav" { NavLink }
    "src/lib/messages/drag-types.d" --> "src/lib/messages/drag-utils" { MessageDragPayload }
    src.hooks.utils --> "src/components/components-nav-utils" {
        fetchMessageList,
        getMessageQueryParams,
    }
    "src/hooks/types.d" --> "src/components/components-nav-utils" { MessageFolder }
    src.components.icons --> "src/components/nav-section-header" { ChevronRight }
    src.lib.utils --> "src/components/nav-section-header" { cn }
    "src/components/reorderable-list-utils" --> "src/components/nav-section-header" {
        readStorage,
        writeStorage,
    }
    "src/components/reorderable-list-types.d" --> "src/components/reorderable-list-utils" {
        ReorderableLayout,
    }
    "src/components/sidebar-state" --> "src/components/sidebar-footer" { useSidebar }
    src.components.shortcuts.index --> "src/components/sidebar-footer" { useShortcuts }
    src.components.icons --> "src/components/sidebar-footer" { Keyboard }
    "src/components/language-provider" --> "src/components/sidebar-footer" { useLanguage }
    src.components.shortcuts.types --> src.components.shortcuts.index;
    "src/components/shortcuts/use-hotkeys" --> src.components.shortcuts.index;
    "src/components/shortcuts/use-shortcuts-enabled" --> src.components.shortcuts.index;
    "src/components/shortcuts/shortcuts-context" --> src.components.shortcuts.index;
    "src/components/shortcuts/command-palette" --> src.components.shortcuts.index;
    "src/components/shortcuts/command-palette-item" --> src.components.shortcuts.index;
    "src/components/shortcuts/command-palette-utils" --> src.components.shortcuts.index;
    "src/components/shortcuts/shortcuts-help-dialog" --> src.components.shortcuts.index;
    src.components.shortcuts.types --> "src/components/shortcuts/use-hotkeys" { ShortcutDefinition }
    "src/components/shortcuts/hotkey-sequence" --> "src/components/shortcuts/use-hotkeys" {
        consumeEvent,
        createSequenceState,
        matchSequence,
        recordKey,
    }
    "src/components/shortcuts/use-hotkeys-utils" --> "src/components/shortcuts/use-hotkeys" {
        hasCommandModifier,
        isModifierKey,
    }
    src.components.shortcuts.types --> "src/components/shortcuts/hotkey-sequence" {
        ShortcutDefinition,
    }
    "src/components/shortcuts/use-hotkeys-utils" --> "src/components/shortcuts/hotkey-sequence" {
        findSequenceMatch,
    }
    src.components.shortcuts.types --> "src/components/shortcuts/use-hotkeys-utils" {
        ShortcutDefinition,
    }
    "src/components/shortcuts/use-shortcuts-enabled-utils" --> "src/components/shortcuts/use-shortcuts-enabled" {
        loadShortcutsEnabled,
        updateShortcutsEnabled,
    }
    src.lib.auth.client --> "src/components/shortcuts/use-shortcuts-enabled-utils" { authFetch }
    src.components.shortcuts.types --> "src/components/shortcuts/use-shortcuts-enabled-utils" {
        ShortcutsSettingsResponse,
    }
    src.components.icons --> "src/components/shortcuts/shortcuts-context" {
        Archive,
        Clock,
        FileText,
        HelpCircle,
        Inbox,
        MailPlus,
        Send,
        Settings,
        ShieldAlert,
        Star,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/shortcuts/shortcuts-context" {
        useLanguage,
    }
    "src/components/compose/compose-context" --> "src/components/shortcuts/shortcuts-context" {
        useCompose,
    }
    src.components.shortcuts.types --> "src/components/shortcuts/shortcuts-context" {
        CommandItem,
        ShortcutDefinition,
    }
    "src/components/shortcuts/use-hotkeys" --> "src/components/shortcuts/shortcuts-context" {
        useHotkeys,
    }
    "src/components/shortcuts/command-palette" --> "src/components/shortcuts/shortcuts-context" {
        CommandPalette,
    }
    "src/components/shortcuts/shortcuts-help-dialog" --> "src/components/shortcuts/shortcuts-context" {
        ShortcutsHelpDialog,
    }
    "src/components/shortcuts/use-shortcuts-enabled" --> "src/components/shortcuts/shortcuts-context" {
        useShortcutsEnabled,
    }
    src.components.icons --> "src/components/shortcuts/command-palette" { CornerDownLeft, Search }
    "src/components/language-provider" --> "src/components/shortcuts/command-palette" {
        useLanguage,
    }
    src.components.shortcuts.types --> "src/components/shortcuts/command-palette" { CommandItem }
    "src/lib/i18n/types.d" --> "src/components/shortcuts/command-palette" { TranslationKey }
    "src/components/shortcuts/command-palette-utils" --> "src/components/shortcuts/command-palette" {
        filterCommands,
        groupCommandsByCategory,
    }
    "src/components/shortcuts/command-palette-item" --> "src/components/shortcuts/command-palette" {
        CommandPaletteItem,
    }
    "src/components/use-dialog-focus" --> "src/components/shortcuts/command-palette" {
        useDialogFocus,
    }
    src.components.shortcuts.types --> "src/components/shortcuts/command-palette-utils" {
        CommandItem,
    }
    src.components.shortcuts.types --> "src/components/shortcuts/command-palette-item" {
        CommandItem,
    }
    src.components.icons --> "src/components/shortcuts/shortcuts-help-dialog" { Keyboard, X }
    "src/components/language-provider" --> "src/components/shortcuts/shortcuts-help-dialog" {
        useLanguage,
    }
    "src/lib/i18n/types.d" --> "src/components/shortcuts/shortcuts-help-dialog" { TranslationKey }
    src.components.shortcuts.types --> "src/components/shortcuts/shortcuts-help-dialog" {
        ShortcutDefinition,
    }
    "src/components/use-dialog-focus" --> "src/components/shortcuts/shortcuts-help-dialog" {
        useDialogFocus,
    }
    src.components.icons --> "src/components/sidebar-header" { Menu, TextAlignJustify }
    "src/components/branding-provider" --> "src/components/sidebar-header" { useBranding }
    "src/components/sidebar-state" --> "src/components/sidebar-header" { useSidebar }
    "src/components/sidebar-state-types.d" --> "src/components/sidebar-header" {
        SidebarHeaderProps,
    }
    src.components.ui.tooltip --> "src/components/sidebar-header" { Tooltip }
    "src/components/language-provider" --> "src/components/sidebar-header" { useLanguage }
    "src/components/sidebar-state-types.d" --> "src/components/sidebar-scaffold" {
        SidebarScaffoldProps,
    }
    src.lib.utils --> "src/components/sidebar-scaffold" { cn }
    "src/components/branding-provider" --> "src/components/sidebar-scaffold" { useBranding }
    "src/components/sidebar-state" --> "src/components/sidebar-scaffold" { useSidebar }
    "src/lib/i18n/types.d" --> "src/components/admin-page-titles" { TranslationKey }
    src.components.icons --> "src/components/sidebar-aside" { Menu }
    "src/components/sidebar-state" --> "src/components/sidebar-aside" { useSidebar }
    "src/components/language-provider" --> "src/components/sidebar-aside" { useLanguage }
    "src/components/branding-provider" --> "src/components/sidebar-aside" { useBranding }
    "src/components/language-provider" --> "src/components/sidebar-resize-boundary" { useLanguage }
    "src/components/ui/resize-handle" --> "src/components/sidebar-resize-boundary" { ResizeHandle }
    "src/components/sidebar-state" --> "src/components/sidebar-resize-boundary" { useSidebar }
    "src/components/column-width-preferences" --> "src/components/sidebar-resize-boundary" {
        saveColumnWidth,
    }
    "src/components/ui/resize-handle-types.d" --> "src/components/ui/resize-handle" {
        ResizeHandleProps,
    }
    "src/components/branding-provider" --> "src/components/route-title" { useBranding }
    "src/components/language-provider" --> "src/components/route-title" { useLanguage }
    "src/components/route-title-utils" --> "src/components/route-title" { getRouteTitleKey }
    "src/components/settings/settings-nav-utils" --> "src/components/route-title-utils" {
        settingsNavSections,
    }
    "src/lib/i18n/types.d" --> "src/components/route-title-utils" { TranslationKey }
    "src/components/settings/settings-nav-types.d" --> "src/components/settings/settings-nav-utils" {
        SettingsNavSection,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/licenses/license-activation" {
        confirmDestructive,
    }
    src.components.icons --> "src/app/(admin)/licenses/license-activation" { CheckCircle2 }
    "src/components/language-provider" --> "src/app/(admin)/licenses/license-activation" {
        useLanguage,
    }
    src.components.ui.badge --> "src/app/(admin)/licenses/license-activation" { Badge }
    src.components.ui.button --> "src/app/(admin)/licenses/license-activation" { Button }
    src.components.ui.card --> "src/app/(admin)/licenses/license-activation" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    src.components.ui.input --> "src/app/(admin)/licenses/license-activation" { Input }
    src.components.ui.label --> "src/app/(admin)/licenses/license-activation" { Label }
    src.components.ui.skeleton --> "src/app/(admin)/licenses/license-activation" { Skeleton }
    "src/lib/licenses/types.d" --> "src/app/(admin)/licenses/license-activation" { LicenseStatus }
    "src/app/(admin)/licenses/types.d" --> "src/app/(admin)/licenses/license-activation" {
        ActivatableLicensePlan,
        LicenseAction,
    }
    "src/app/(admin)/licenses/utils" --> "src/app/(admin)/licenses/license-activation" {
        formatLicensePlan,
        loadLicenseStatus,
        runLicenseAction,
    }
    src.lib.i18n.utils --> "src/app/(admin)/licenses/utils" { Translator, defaultTranslator }
    src.components.icons --> "src/app/(admin)/licenses/utils" { Building2, Sparkles }
    "src/app/(admin)/licenses/types.d" --> "src/app/(admin)/licenses/utils" {
        ActivatableLicensePlan,
        LicenseAction,
        LicensePlan,
        LicenseResponse,
    }
    src.lib.auth.client --> "src/app/(admin)/licenses/utils" { authFetch }
    src.lib.time.utils --> "src/app/(admin)/licenses/utils" { formatUserDate }
    src.lib.licenses.constants --> "src/app/(admin)/licenses/utils" { LICENSE_STATUS_CHANGED_EVENT }
    src.lib.i18n.server --> "src/app/(admin)/licenses/page" { getServerTranslator }
    src.components.icons --> "src/app/(admin)/licenses/page" { Check, ExternalLink }
    src.components.ui.badge --> "src/app/(admin)/licenses/page" { Badge }
    src.components.ui.button --> "src/app/(admin)/licenses/page" { Button }
    src.components.ui.card --> "src/app/(admin)/licenses/page" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    "src/app/(admin)/licenses/license-activation" --> "src/app/(admin)/licenses/page" {
        LicenseActivation,
    }
    "src/app/(admin)/licenses/utils" --> "src/app/(admin)/licenses/page" { LICENSE_PLANS }
    src.lib.cloudflare --> src.lib.i18n.server { getEnv }
    src.lib.i18n.utils --> src.lib.i18n.server {
        LOCALE_COOKIE,
        createTranslator,
        loadMessages,
        resolveLocale,
    }
    "src/lib/i18n/types.d" --> src.lib.i18n.server { Locale, Messages }
    "src/components/route-loading-bar" --> "src/app/(admin)/loading" { RouteLoadingBar }
    src.components.icons --> "src/app/(admin)/mailboxes/[id]/MailboxAvatarForm" {
        Camera,
        LoaderCircle,
        User,
    }
    "src/components/language-provider" --> "src/app/(admin)/mailboxes/[id]/MailboxAvatarForm" {
        useLanguage,
    }
    "src/lib/mailboxes/avatar-client" --> "src/app/(admin)/mailboxes/[id]/MailboxAvatarForm" {
        dispatchMailboxAvatarChanged,
    }
    src.components.ui.input --> "src/app/(admin)/mailboxes/[id]/MailboxAvatarForm" { Input }
    "src/components/progressive-avatar-image" --> "src/app/(admin)/mailboxes/[id]/MailboxAvatarForm" {
        ProgressiveAvatarImage,
    }
    "src/app/(admin)/mailboxes/[id]/types.d" --> "src/app/(admin)/mailboxes/[id]/MailboxAvatarForm" {
        MailboxAvatarFormProps,
    }
    "src/app/(admin)/mailboxes/[id]/avatar-utils" --> "src/app/(admin)/mailboxes/[id]/MailboxAvatarForm" {
        MAILBOX_AVATAR_ACCEPT,
        getMailboxAvatarUrl,
        uploadMailboxAvatar,
        validateMailboxAvatar,
    }
    src.lib.auth.client --> "src/app/(admin)/mailboxes/[id]/avatar-utils" { authFetch }
    "src/lib/avatar-upload-client" --> "src/app/(admin)/mailboxes/[id]/avatar-utils" {
        appendOptimizedAvatar,
    }
    "src/components/mailbox-provider-utils" --> "src/app/(admin)/mailboxes/[id]/avatar-utils" {
        clearMailboxesCache,
    }
    "src/components/settings/profile-avatar-form-utils" --> "src/app/(admin)/mailboxes/[id]/avatar-utils" {
        PROFILE_AVATAR_ACCEPT,
        validateProfileAvatar,
    }
    "src/app/(admin)/mailboxes/[id]/types.d" --> "src/app/(admin)/mailboxes/[id]/avatar-utils" {
        MailboxAvatarUploadResponse,
    }
    src.lib.auth.client --> "src/components/settings/profile-avatar-form-utils" { authFetch }
    "src/lib/avatar-upload-client" --> "src/components/settings/profile-avatar-form-utils" {
        MAX_SOURCE_AVATAR_SIZE,
        appendOptimizedAvatar,
    }
    "src/components/mailbox-provider-utils" --> "src/components/settings/profile-avatar-form-utils" {
        clearMailboxesCache,
    }
    "src/components/settings/types.d" --> "src/components/settings/profile-avatar-form-utils" {
        ProfileAvatarUploadResponse,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/mailboxes/[id]/page" {
        confirmDestructive,
    }
    src.components.icons --> "src/app/(admin)/mailboxes/[id]/page" {
        AtSign,
        Check,
        Copy,
        Save,
        Sparkles,
        Trash2,
        UserPlus,
    }
    "src/components/language-provider" --> "src/app/(admin)/mailboxes/[id]/page" { useLanguage }
    src.components.ui.badge --> "src/app/(admin)/mailboxes/[id]/page" { Badge }
    src.components.ui.button --> "src/app/(admin)/mailboxes/[id]/page" { Button }
    src.components.ui.card --> "src/app/(admin)/mailboxes/[id]/page" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    src.components.ui.input --> "src/app/(admin)/mailboxes/[id]/page" { Input }
    src.components.ui.checkbox --> "src/app/(admin)/mailboxes/[id]/page" { Checkbox }
    src.components.ui.label --> "src/app/(admin)/mailboxes/[id]/page" { Label }
    src.components.ui.select --> "src/app/(admin)/mailboxes/[id]/page" { Select }
    src.components.ui.skeleton --> "src/app/(admin)/mailboxes/[id]/page" { Skeleton }
    src.components.ui.switch --> "src/app/(admin)/mailboxes/[id]/page" { Switch }
    "src/app/(admin)/mailboxes/[id]/utils" --> "src/app/(admin)/mailboxes/[id]/page" {
        createMailboxAlias,
        deleteMailbox,
        deleteMailboxAlias,
        fetchMailbox,
        fetchMailboxAliases,
        fetchSharedInboxAccess,
        getMailboxAddress,
        grantSharedInboxAccess,
        revokeSharedInboxAccess,
        updateMailboxAlias,
        updateMailboxSettings,
    }
    "src/app/(admin)/mailboxes/utils" --> "src/app/(admin)/mailboxes/[id]/page" { getMailboxesBase }
    "src/app/(admin)/mailboxes/[id]/MailboxAvatarForm" --> "src/app/(admin)/mailboxes/[id]/page" {
        default,
    }
    src.lib.auth.client --> "src/app/(admin)/mailboxes/[id]/utils" { authFetch }
    "src/components/mailbox-provider-utils" --> "src/app/(admin)/mailboxes/[id]/utils" {
        clearMailboxesCache,
    }
    "src/app/(admin)/mailboxes/[id]/types.d" --> "src/app/(admin)/mailboxes/[id]/utils" {
        MailboxAliasesResponse,
        MailboxDetail,
        MailboxDetailResponse,
        SharedInboxAccessResponse,
    }
    "src/app/(admin)/mailboxes/types.d" --> "src/app/(admin)/mailboxes/utils" { Mailbox }
    "src/components/page-header-utils" --> "src/app/(admin)/mailboxes/page" {
        mobilePrimaryActionClass,
    }
    src.components.icons --> "src/app/(admin)/mailboxes/page" { Plus }
    "src/components/language-provider" --> "src/app/(admin)/mailboxes/page" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/mailboxes/page" { Button }
    src.components.ui.dialog --> "src/app/(admin)/mailboxes/page" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
        DialogTrigger,
    }
    src.components.ui.input --> "src/app/(admin)/mailboxes/page" { Input }
    src.components.ui.label --> "src/app/(admin)/mailboxes/page" { Label }
    src.components.ui.select --> "src/app/(admin)/mailboxes/page" { Select }
    src.components.ui.list --> "src/app/(admin)/mailboxes/page" { List, ListRow }
    "src/components/page-skeletons" --> "src/app/(admin)/mailboxes/page" { SectionRowSkeleton }
    "src/components/mailbox-provider-utils" --> "src/app/(admin)/mailboxes/page" {
        clearMailboxesCache,
    }
    "src/components/progressive-avatar-image" --> "src/app/(admin)/mailboxes/page" {
        ProgressiveAvatarImage,
    }
    src.lib.auth.client --> "src/app/(admin)/mailboxes/page" { authFetch }
    "src/app/(admin)/mailboxes/types.d" --> "src/app/(admin)/mailboxes/page" {
        CurrentAccountResponse,
        Domain,
        MailboxOwner,
        MailboxesResponse,
    }
    "src/app/(admin)/accounts/utils" --> "src/app/(admin)/mailboxes/page" { formatAccountDateTime }
    "src/app/(admin)/mailboxes/utils" --> "src/app/(admin)/mailboxes/page" {
        getMailboxAddress,
        getMailboxName,
        getMailboxesBase,
    }
    "src/components/language-provider" --> "src/app/(admin)/routing/page" { useLanguage }
    "src/components/settings/domain-routing/domain-routing" --> "src/app/(admin)/routing/page" {
        DomainRouting,
    }
    "src/components/settings/domain-routing/routing-rule-select" --> "src/app/(admin)/routing/page" {
        RoutingRuleSelect,
    }
    src.components.ui.label --> "src/app/(admin)/routing/page" { Label }
    src.components.ui.skeleton --> "src/app/(admin)/routing/page" { Skeleton }
    "src/app/(admin)/routing/utils" --> "src/app/(admin)/routing/page" { fetchAdminRoutingDomains }
    src.components.icons --> "src/components/settings/domain-routing/domain-routing" {
        Ban,
        Forward,
        Inbox,
        Info,
        Pencil,
        Plus,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/settings/domain-routing/domain-routing" {
        useLanguage,
    }
    src.components.ui.badge --> "src/components/settings/domain-routing/domain-routing" { Badge }
    src.components.ui.button --> "src/components/settings/domain-routing/domain-routing" { Button }
    src.components.ui.card --> "src/components/settings/domain-routing/domain-routing" {
        Card,
        CardContent,
        CardHeader,
        CardTitle,
    }
    src.components.ui.dialog --> "src/components/settings/domain-routing/domain-routing" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/settings/domain-routing/domain-routing" { Input }
    src.components.ui.label --> "src/components/settings/domain-routing/domain-routing" { Label }
    "src/components/settings/domain-routing/routing-rule-select" --> "src/components/settings/domain-routing/domain-routing" {
        RoutingRuleSelect,
    }
    src.components.ui.switch --> "src/components/settings/domain-routing/domain-routing" { Switch }
    src.components.ui.tooltip --> "src/components/settings/domain-routing/domain-routing" {
        Tooltip,
    }
    "src/components/page-skeletons" --> "src/components/settings/domain-routing/domain-routing" {
        CardGridSkeleton,
    }
    "src/components/mailbox-provider" --> "src/components/settings/domain-routing/domain-routing" {
        useSelectedMailbox,
    }
    "src/hooks/use-current-user" --> "src/components/settings/domain-routing/domain-routing" {
        useCurrentUser,
    }
    src.lib.auth.admin --> "src/components/settings/domain-routing/domain-routing" {
        canManageDomains,
    }
    "src/lib/http/client-error" --> "src/components/settings/domain-routing/domain-routing" {
        ClientRequestError,
    }
    "src/components/settings/security-status-store" --> "src/components/settings/domain-routing/domain-routing" {
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/components/settings/domain-routing/domain-routing" {
        StepUpDialog,
    }
    "src/lib/email/mail-type-rule" --> "src/components/settings/domain-routing/domain-routing" {
        MAIL_TYPE_UNSAFE_ACTION,
    }
    "src/components/settings/domain-routing/types.d" --> "src/components/settings/domain-routing/domain-routing" {
        DomainRoutingProps,
        DomainRule,
        DomainRuleInput,
    }
    "src/components/settings/domain-routing/utils" --> "src/components/settings/domain-routing/domain-routing" {
        ACTION_LABELS,
        MATCH_FIELD_LABELS,
        MATCH_OPERATOR_LABELS,
        createDomainRule,
        deleteDomainRule,
        describeRule,
        emptyRuleInput,
        fetchDomainRules,
        formatLastMatched,
        ruleToInput,
        updateDomainRule,
    }
    src.components.ui.select --> "src/components/settings/domain-routing/routing-rule-select" {
        Select,
    }
    "src/components/ui/select-types.d" --> "src/components/settings/domain-routing/routing-rule-select" {
        SelectProps,
    }
    src.lib.utils --> "src/components/settings/domain-routing/routing-rule-select" { cn }
    "src/lib/http/client-error" --> "src/components/settings/domain-routing/utils" { requestError }
    "src/lib/i18n/types.d" --> "src/components/settings/domain-routing/utils" { TranslationKey }
    src.lib.i18n.utils --> "src/components/settings/domain-routing/utils" {
        Translator,
        defaultTranslator,
    }
    src.lib.auth.client --> "src/components/settings/domain-routing/utils" { authFetch }
    "src/lib/email/mail-type-rule" --> "src/components/settings/domain-routing/utils" {
        ruleErrorMessage,
    }
    src.lib.time.utils --> "src/components/settings/domain-routing/utils" { formatUserDate }
    "src/components/settings/domain-routing/types.d" --> "src/components/settings/domain-routing/utils" {
        DomainRule,
        DomainRuleField,
        DomainRuleInput,
        DomainRuleMailbox,
        DomainRuleOperator,
    }
    src.lib.auth.client --> "src/app/(admin)/routing/utils" { authFetch }
    "src/app/(admin)/routing/types.d" --> "src/app/(admin)/routing/utils" {
        AdminRoutingDomainsResponse,
    }
    src.components.icons --> "src/app/(admin)/spam-filter/page" { ExternalLink }
    "src/components/language-provider" --> "src/app/(admin)/spam-filter/page" { useLanguage }
    src.components.ui.button --> "src/app/(admin)/spam-filter/page" { Button }
    src.components.ui.card --> "src/app/(admin)/spam-filter/page" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    src.components.ui.input --> "src/app/(admin)/spam-filter/page" { Input }
    src.components.ui.label --> "src/app/(admin)/spam-filter/page" { Label }
    src.components.ui.switch --> "src/app/(admin)/spam-filter/page" { Switch }
    src.components.ui.textarea --> "src/app/(admin)/spam-filter/page" { Textarea }
    "src/lib/spam/types.d" --> "src/app/(admin)/spam-filter/page" { SpamKeySource }
    "src/app/(admin)/spam-filter/types.d" --> "src/app/(admin)/spam-filter/page" {
        SpamFilterSettingsResponse,
        SpamKeyField,
    }
    "src/app/(admin)/spam-filter/utils" --> "src/app/(admin)/spam-filter/page" {
        ABUSECH_SIGNUP_URL,
        SPAMHAUS_SIGNUP_URL,
        formatBrandLines,
        loadSpamFilterSettings,
        parseBrandLines,
        saveSpamFilterSettings,
    }
    src.lib.auth.client --> "src/app/(admin)/spam-filter/utils" { authFetch }
    "src/lib/spam/types.d" --> "src/app/(admin)/spam-filter/utils" { SpamBrand }
    "src/app/(admin)/spam-filter/types.d" --> "src/app/(admin)/spam-filter/utils" {
        BrandLinesResult,
        SpamFilterSettingsResponse,
        SpamFilterUpdate,
    }
    src.components.icons --> "src/app/(admin)/webhooks/deliveries" { RotateCw }
    "src/components/language-provider" --> "src/app/(admin)/webhooks/deliveries" { useLanguage }
    src.components.ui.badge --> "src/app/(admin)/webhooks/deliveries" { Badge }
    src.components.ui.button --> "src/app/(admin)/webhooks/deliveries" { Button }
    "src/app/(admin)/webhooks/types.d" --> "src/app/(admin)/webhooks/deliveries" { WebhookDelivery }
    "src/app/(admin)/webhooks/utils" --> "src/app/(admin)/webhooks/deliveries" {
        DELIVERY_STATUS_LABELS,
        fetchDeliveries,
        formatDuration,
        formatTimestamp,
        isRetryable,
        retryDelivery,
    }
    "src/lib/i18n/types.d" --> "src/app/(admin)/webhooks/utils" { TranslationKey }
    src.lib.i18n.utils --> "src/app/(admin)/webhooks/utils" { defaultTranslator }
    src.lib.auth.client --> "src/app/(admin)/webhooks/utils" { authFetch }
    "src/lib/http/client-error" --> "src/app/(admin)/webhooks/utils" { requestError }
    src.lib.time.utils --> "src/app/(admin)/webhooks/utils" { formatUserDate }
    "src/app/(admin)/webhooks/types.d" --> "src/app/(admin)/webhooks/utils" {
        CreateWebhookInput,
        UpdateWebhookInput,
        Webhook,
        WebhookDelivery,
        WebhookEvent,
    }
    "src/components/page-header-utils" --> "src/app/(admin)/webhooks/page" {
        mobilePrimaryActionClass,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(admin)/webhooks/page" {
        confirmDestructive,
        confirmDialog,
    }
    src.components.icons --> "src/app/(admin)/webhooks/page" {
        Activity,
        Plus,
        RefreshCw,
        Send,
        Trash2,
    }
    "src/components/language-provider" --> "src/app/(admin)/webhooks/page" { useLanguage }
    src.components.ui.badge --> "src/app/(admin)/webhooks/page" { Badge }
    src.components.ui.button --> "src/app/(admin)/webhooks/page" { Button }
    src.components.ui.card --> "src/app/(admin)/webhooks/page" { Card, CardContent }
    src.components.ui.dialog --> "src/app/(admin)/webhooks/page" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/app/(admin)/webhooks/page" { Input }
    src.components.ui.label --> "src/app/(admin)/webhooks/page" { Label }
    src.components.ui.switch --> "src/app/(admin)/webhooks/page" { Switch }
    "src/components/page-skeletons" --> "src/app/(admin)/webhooks/page" { SectionRowSkeleton }
    "src/app/(admin)/webhooks/types.d" --> "src/app/(admin)/webhooks/page" { Webhook, WebhookEvent }
    "src/app/(admin)/webhooks/utils" --> "src/app/(admin)/webhooks/page" {
        WEBHOOK_EVENTS,
        createWebhook,
        deleteWebhook,
        fetchWebhooks,
        testWebhook,
        updateWebhook,
    }
    "src/app/(admin)/webhooks/deliveries" --> "src/app/(admin)/webhooks/page" { WebhookDeliveries }
    "src/components/settings/security-status-store" --> "src/app/(admin)/webhooks/page" {
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/app/(admin)/webhooks/page" { StepUpDialog }
    "src/lib/http/client-error" --> "src/app/(admin)/webhooks/page" { ClientRequestError }
    src.components.ui.checkbox --> "src/app/(admin)/webhooks/page" { Checkbox }
    "src/app/home-server-utils" --> "src/app/(auth)/auth-metadata" { getHomeBranding }
    src.lib.i18n.server --> "src/app/(auth)/auth-metadata" { getServerTranslator }
    "src/lib/i18n/types.d" --> "src/app/(auth)/auth-metadata" { TranslationKey }
    src.lib.branding.service --> "src/app/home-server-utils" { getBranding }
    src.lib.cloudflare --> "src/app/home-server-utils" { getEnv }
    "src/components/branding-provider-utils" --> "src/app/home-server-utils" { DEFAULT_BRANDING }
    src.db.index --> src.lib.branding.service { getDb }
    src.db.schema.index --> src.lib.branding.service { appSettings }
    "src/lib/branding/types.d" --> src.lib.branding.service { Branding }
    src.lib.licenses.service --> src.lib.branding.service { getLicenseEntitlements }
    src.components.icons --> "src/app/(auth)/forgot-password/forgot-password-client" { KeyRound }
    "src/components/language-provider" --> "src/app/(auth)/forgot-password/forgot-password-client" {
        useLanguage,
    }
    "src/components/auth/auth-shell" --> "src/app/(auth)/forgot-password/forgot-password-client" {
        AuthShell,
    }
    src.components.auth.turnstile --> "src/app/(auth)/forgot-password/forgot-password-client" {
        TurnstileField,
    }
    src.components.ui.button --> "src/app/(auth)/forgot-password/forgot-password-client" { Button }
    src.components.ui.input --> "src/app/(auth)/forgot-password/forgot-password-client" { Input }
    src.components.ui.label --> "src/app/(auth)/forgot-password/forgot-password-client" { Label }
    "src/app/(auth)/forgot-password/utils" --> "src/app/(auth)/forgot-password/forgot-password-client" {
        requestPasswordReset,
    }
    "src/components/branding-provider" --> "src/components/auth/auth-shell" { useBranding }
    "src/components/language-selector" --> "src/components/auth/auth-shell" { LanguageSelector }
    "src/components/auth/types.d" --> "src/components/auth/auth-shell" { AuthShellProps }
    src.lib.i18n.locales --> "src/components/language-selector" { locales, supportedLocales }
    src.lib.i18n.utils --> "src/components/language-selector" { resolveLocale }
    "src/components/language-provider" --> "src/components/language-selector" { useLanguage }
    src.components.ui.select --> "src/components/language-selector" { Select }
    src.components.ui.input --> src.components.auth.turnstile { Input }
    "src/components/auth/auth-guard" --> "src/app/(auth)/forgot-password/page" { AuthGuard }
    "src/app/(auth)/auth-metadata" --> "src/app/(auth)/forgot-password/page" { authPageMetadata }
    "src/app/(auth)/forgot-password/forgot-password-client" --> "src/app/(auth)/forgot-password/page" {
        ForgotPasswordClient,
    }
    src.components.icons --> "src/app/(auth)/login/login-client" { KeyRound, Mail, ShieldCheck }
    "src/components/language-provider" --> "src/app/(auth)/login/login-client" { useLanguage }
    "src/components/auth/auth-shell" --> "src/app/(auth)/login/login-client" { AuthShell }
    src.components.ui.button --> "src/app/(auth)/login/login-client" { Button }
    src.components.ui.input --> "src/app/(auth)/login/login-client" { Input }
    src.components.ui.label --> "src/app/(auth)/login/login-client" { Label }
    src.components.auth.turnstile --> "src/app/(auth)/login/login-client" { TurnstileField }
    "src/lib/auth/error-messages" --> "src/app/(auth)/login/login-client" { authErrorText }
    "src/lib/auth/webauthn/browser-errors" --> "src/app/(auth)/login/login-client" {
        isPasskeyCancellation,
    }
    "src/app/(auth)/login/utils" --> "src/app/(auth)/login/login-client" {
        finishPasskeyLogin,
        requestPasskeyLoginOptions,
        submitLogin,
        submitMfaCode,
        submitPasskeyLogin,
        submitPasskeyMfa,
    }
    src.lib.auth.client --> "src/app/(auth)/login/utils" { persistAuthSession }
    "src/app/(auth)/login/types.d" --> "src/app/(auth)/login/utils" { LoginResult }
    "src/components/auth/auth-guard" --> "src/app/(auth)/login/page" { AuthGuard }
    src.lib.auth.setup --> "src/app/(auth)/login/page" { hasAdminAccount }
    src.lib.auth.session --> "src/app/(auth)/login/page" { SESSION_COOKIE, getUserFromSession }
    src.lib.cloudflare --> "src/app/(auth)/login/page" { getEnv }
    "src/app/(auth)/auth-metadata" --> "src/app/(auth)/login/page" { authPageMetadata }
    "src/app/(auth)/login/login-client" --> "src/app/(auth)/login/page" { LoginClient }
    src.db.index --> src.lib.auth.setup { getDb }
    src.db.schema.index --> src.lib.auth.setup { users }
    "src/lib/auth/setup-utils" --> src.lib.auth.setup { isMissingUsersTableError }
    src.components.icons --> "src/app/(auth)/onboarding/onboarding-client" {
        AlertTriangle,
        ArrowRight,
        CheckCircle2,
        LoaderCircle,
        MailPlus,
    }
    "src/components/language-provider" --> "src/app/(auth)/onboarding/onboarding-client" {
        useLanguage,
    }
    "src/components/auth/auth-shell" --> "src/app/(auth)/onboarding/onboarding-client" { AuthShell }
    src.components.ui.button --> "src/app/(auth)/onboarding/onboarding-client" { Button }
    src.components.ui.input --> "src/app/(auth)/onboarding/onboarding-client" { Input }
    src.components.ui.label --> "src/app/(auth)/onboarding/onboarding-client" { Label }
    src.components.ui.switch --> "src/app/(auth)/onboarding/onboarding-client" { Switch }
    "src/app/(auth)/onboarding/utils" --> "src/app/(auth)/onboarding/onboarding-client" {
        checkDomain,
        createDomain,
        createMailbox,
        getDomains,
    }
    "src/app/(auth)/onboarding/types.d" --> "src/app/(auth)/onboarding/onboarding-client" {
        DomainPreflight,
    }
    src.lib.http.response --> "src/app/(auth)/onboarding/utils" { readResponseJson }
    src.lib.auth.client --> "src/app/(auth)/onboarding/utils" { authFetch }
    "src/app/(auth)/onboarding/types.d" --> "src/app/(auth)/onboarding/utils" {
        DomainCreateResult,
        DomainListResult,
        DomainPreflightResponse,
        MailboxCreateResult,
    }
    src.components.icons --> "src/app/(auth)/register/register-client" {
        AlertTriangle,
        ArrowRight,
        CheckCircle2,
        LoaderCircle,
        MailPlus,
        XCircle,
    }
    "src/components/language-provider" --> "src/app/(auth)/register/register-client" { useLanguage }
    "src/components/auth/auth-shell" --> "src/app/(auth)/register/register-client" { AuthShell }
    src.components.ui.button --> "src/app/(auth)/register/register-client" { Button }
    src.components.ui.checkbox --> "src/app/(auth)/register/register-client" { Checkbox }
    src.components.ui.input --> "src/app/(auth)/register/register-client" { Input }
    src.components.ui.label --> "src/app/(auth)/register/register-client" { Label }
    src.components.ui.switch --> "src/app/(auth)/register/register-client" { Switch }
    src.components.auth.turnstile --> "src/app/(auth)/register/register-client" { TurnstileField }
    "src/app/(auth)/register/utils" --> "src/app/(auth)/register/register-client" {
        checkExistingMx,
        getSetupStatus,
        prepareSetup,
        submitPrimaryDomain,
        submitRegistration,
    }
    "src/app/(auth)/register/types.d" --> "src/app/(auth)/register/register-client" {
        DomainPreflight,
        DomainSetupResult,
        SetupRequirementCheck,
    }
    src.lib.http.response --> "src/app/(auth)/register/utils" { readResponseJson }
    src.lib.auth.client --> "src/app/(auth)/register/utils" { clearClientSessionToken }
    "src/app/(auth)/register/types.d" --> "src/app/(auth)/register/utils" {
        DomainSetupResult,
        MxCheckResult,
        RegisterResult,
        SetupPreparationResult,
        SetupStatus,
    }
    "src/components/auth/auth-guard" --> "src/app/(auth)/reset-password/page" { AuthGuard }
    "src/app/(auth)/auth-metadata" --> "src/app/(auth)/reset-password/page" { authPageMetadata }
    "src/app/(auth)/reset-password/reset-password-client" --> "src/app/(auth)/reset-password/page" {
        ResetPasswordClient,
    }
    src.components.icons --> "src/app/(auth)/reset-password/reset-password-client" { LockKeyhole }
    "src/components/language-provider" --> "src/app/(auth)/reset-password/reset-password-client" {
        useLanguage,
    }
    "src/components/auth/auth-shell" --> "src/app/(auth)/reset-password/reset-password-client" {
        AuthShell,
    }
    src.components.ui.button --> "src/app/(auth)/reset-password/reset-password-client" { Button }
    src.components.ui.input --> "src/app/(auth)/reset-password/reset-password-client" { Input }
    src.components.ui.label --> "src/app/(auth)/reset-password/reset-password-client" { Label }
    "src/app/(auth)/reset-password/utils" --> "src/app/(auth)/reset-password/reset-password-client" {
        confirmPasswordReset,
    }
    "src/components/auth/auth-guard" --> "src/app/(auth)/setup/page" { AuthGuard }
    src.lib.auth.session --> "src/app/(auth)/setup/page" { SESSION_COOKIE, getUserFromSession }
    src.lib.auth.setup --> "src/app/(auth)/setup/page" { hasAdminAccount }
    src.lib.cloudflare --> "src/app/(auth)/setup/page" { getEnv }
    src.lib.user --> "src/app/(auth)/setup/page" { getPrimaryDomain }
    "src/app/(auth)/onboarding/onboarding-client" --> "src/app/(auth)/setup/page" {
        OnboardingClient,
    }
    "src/app/(auth)/register/register-client" --> "src/app/(auth)/setup/page" { RegisterClient }
    "src/components/auth/auth-guard" --> "src/app/(auth)/setup/passkey/page" { AuthGuard }
    src.lib.auth.webauthn.grants --> "src/app/(auth)/setup/passkey/page" { SETUP_COOKIE }
    "src/app/(auth)/setup/passkey/passkey-setup-client" --> "src/app/(auth)/setup/passkey/page" {
        PasskeySetupClient,
    }
    src.components.icons --> "src/app/(auth)/setup/passkey/passkey-setup-client" { KeyRound }
    "src/components/language-provider" --> "src/app/(auth)/setup/passkey/passkey-setup-client" {
        useLanguage,
    }
    "src/components/auth/auth-shell" --> "src/app/(auth)/setup/passkey/passkey-setup-client" {
        AuthShell,
    }
    src.components.ui.button --> "src/app/(auth)/setup/passkey/passkey-setup-client" { Button }
    src.components.ui.input --> "src/app/(auth)/setup/passkey/passkey-setup-client" { Input }
    src.components.ui.label --> "src/app/(auth)/setup/passkey/passkey-setup-client" { Label }
    "src/lib/auth/error-messages" --> "src/app/(auth)/setup/passkey/passkey-setup-client" {
        authErrorText,
    }
    "src/lib/auth/webauthn/browser-errors" --> "src/app/(auth)/setup/passkey/passkey-setup-client" {
        isPasskeyCancellation,
        isPasskeyUnsupported,
    }
    "src/app/(auth)/setup/passkey/utils" --> "src/app/(auth)/setup/passkey/passkey-setup-client" {
        finishPasskeySetup,
        loadPasskeySetupContext,
        startPasskeySetup,
    }
    "src/app/(auth)/setup/passkey/types.d" --> "src/app/(auth)/setup/passkey/passkey-setup-client" {
        PasskeySetupContext,
    }
    src.lib.auth.client --> "src/app/(auth)/setup/passkey/utils" { persistAuthSession }
    "src/app/(auth)/setup/passkey/types.d" --> "src/app/(auth)/setup/passkey/utils" {
        PasskeySetupContext,
        PasskeySetupOptionsResponse,
        PasskeySetupResult,
    }
    src.components.icons --> "src/app/(calendar)/booking/booking-editor" {
        CalendarDays,
        ChevronDown,
        Clock3,
        Mail,
        MapPin,
        MoreHorizontal,
        Plus,
        Trash2,
        UserRound,
    }
    "src/lib/booking/confirmation-utils" --> "src/app/(calendar)/booking/booking-editor" {
        BOOKING_TEMPLATE_PLACEHOLDERS,
        CONFIRMATION_BODY_MAX,
        CONFIRMATION_SUBJECT_MAX,
        DEFAULT_CONFIRMATION_BODY,
        DEFAULT_CONFIRMATION_SUBJECT,
    }
    "src/components/language-provider" --> "src/app/(calendar)/booking/booking-editor" {
        useLanguage,
    }
    "src/lib/folders/color-keys" --> "src/app/(calendar)/booking/booking-editor" { folderColorKeys }
    "src/lib/i18n/types.d" --> "src/app/(calendar)/booking/booking-editor" { TranslationKey }
    src.components.ui.button --> "src/app/(calendar)/booking/booking-editor" { Button }
    src.components.ui.input --> "src/app/(calendar)/booking/booking-editor" { Input }
    src.components.ui.textarea --> "src/app/(calendar)/booking/booking-editor" { Textarea }
    src.lib.folders.colors --> "src/app/(calendar)/booking/booking-editor" { FOLDER_COLOR_OPTIONS }
    src.lib.booking.utils --> "src/app/(calendar)/booking/booking-editor" { slugifyBookingName }
    "src/app/(calendar)/booking/editor-types.d" --> "src/app/(calendar)/booking/booking-editor" {
        BookingEditorProps,
    }
    "src/app/(calendar)/booking/types.d" --> "src/app/(calendar)/booking/booking-editor" {
        BookingEditorSection,
    }
    "src/app/(calendar)/booking/utils" --> "src/app/(calendar)/booking/booking-editor" {
        WEEKDAYS,
        bookingFormWithName,
        durationLabel,
        formAvailabilityLabel,
        matchBookingHost,
        nextBookingTimeRange,
    }
    "src/app/(calendar)/booking/booking-host-avatar" --> "src/app/(calendar)/booking/booking-editor" {
        BookingHostAvatar,
    }
    src.components.ui.select --> "src/app/(calendar)/booking/booking-editor" { Select }
    src.lib.calendar.utils --> "src/lib/booking/confirmation-utils" { createCalendarInvitation }
    src.lib.calendar.ics --> src.lib.calendar.utils {
        escapeIcsText,
        formatIcsUtc,
        isIcsAddress,
        joinIcsLines,
    }
    "src/lib/i18n/types.d" --> "src/lib/folders/color-keys" { TranslationKey }
    "src/lib/folders/types.d" --> "src/lib/folders/color-keys" { FolderColor }
    src.lib.time.utils --> src.lib.booking.utils {
        dateFromZonedFields,
        isValidTimeZone,
        zonedDateFields,
    }
    "src/lib/booking/types.d" --> src.lib.booking.utils {
        BookingEventInput,
        BookingEventRecord,
        BookingTimeRange,
    }
    src.lib.calendar.colors --> src.lib.booking.utils { normalizeCalendarColor }
    src.lib.folders.colors --> src.lib.calendar.colors { DEFAULT_FOLDER_COLOR, FOLDER_COLOR_VALUES }
    "src/lib/folders/types.d" --> src.lib.calendar.colors { FolderColor }
    "src/lib/i18n/types.d" --> "src/app/(calendar)/booking/utils" { TranslationKey }
    src.lib.i18n.utils --> "src/app/(calendar)/booking/utils" { Translator, defaultTranslator }
    "src/app/(calendar)/booking/types.d" --> "src/app/(calendar)/booking/utils" {
        BookingEvent,
        BookingForm,
        BookingHost,
        BookingHostMatch,
    }
    src.lib.booking.utils --> "src/app/(calendar)/booking/utils" {
        parseBookingTimeRanges,
        slugifyBookingName,
        timeToMinutes,
    }
    "src/lib/booking/types.d" --> "src/app/(calendar)/booking/utils" { BookingTimeRange }
    src.lib.folders.colors --> "src/app/(calendar)/booking/utils" { DEFAULT_FOLDER_COLOR }
    src.lib.calendar.colors --> "src/app/(calendar)/booking/utils" { normalizeCalendarColor }
    src.lib.booking.hosts --> "src/app/(calendar)/booking/utils" { parseBookingHostIds }
    src.db.index --> src.lib.booking.hosts { getDb }
    src.db.schema.index --> src.lib.booking.hosts { users }
    "src/components/language-provider" --> "src/app/(calendar)/booking/booking-host-avatar" {
        useLanguage,
    }
    "src/components/progressive-avatar-image" --> "src/app/(calendar)/booking/booking-host-avatar" {
        ProgressiveAvatarImage,
    }
    "src/lib/avatar-colors" --> "src/app/(calendar)/booking/booking-host-avatar" {
        getAvatarColorStyle,
    }
    "src/app/(calendar)/booking/types.d" --> "src/app/(calendar)/booking/booking-host-avatar" {
        BookingHostAvatarProps,
    }
    "src/components/language-provider" --> "src/app/(calendar)/booking/booking-list-skeleton" {
        useLanguage,
    }
    src.lib.folders.colors --> "src/app/(calendar)/booking/default-events" { DEFAULT_FOLDER_COLOR }
    "src/app/(calendar)/booking/types.d" --> "src/app/(calendar)/booking/default-events" {
        BookingEvent,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(calendar)/booking/page" { confirmDestructive }
    "src/components/page-header-utils" --> "src/app/(calendar)/booking/page" {
        mobilePrimaryActionClass,
    }
    src.components.icons --> "src/app/(calendar)/booking/page" {
        CalendarDays,
        Check,
        Clock3,
        Copy,
        ExternalLink,
        MapPin,
        MoreHorizontal,
        Plus,
    }
    "src/components/language-provider" --> "src/app/(calendar)/booking/page" { useLanguage }
    src.components.ui.button --> "src/app/(calendar)/booking/page" { Button }
    "src/components/route-loading-bar-portal" --> "src/app/(calendar)/booking/page" {
        RouteLoadingBarPortal,
    }
    src.lib.auth.client --> "src/app/(calendar)/booking/page" { authFetch }
    src.lib.time.utils --> "src/app/(calendar)/booking/page" { getUserTimeZone }
    "src/components/sidebar-state" --> "src/app/(calendar)/booking/page" { useSidebar }
    "src/app/(calendar)/upcoming-sidebar" --> "src/app/(calendar)/booking/page" { UpcomingSidebar }
    "src/app/(calendar)/booking/booking-editor" --> "src/app/(calendar)/booking/page" {
        BookingEditor,
    }
    "src/app/(calendar)/booking/booking-list-skeleton" --> "src/app/(calendar)/booking/page" {
        BookingListSkeleton,
    }
    "src/app/(calendar)/booking/default-events" --> "src/app/(calendar)/booking/page" {
        visibleBookingEvents,
    }
    "src/app/(calendar)/booking/types.d" --> "src/app/(calendar)/booking/page" {
        BookingEvent,
        BookingForm,
        BookingHost,
    }
    "src/app/(calendar)/booking/utils" --> "src/app/(calendar)/booking/page" {
        availabilityLabel,
        durationLabel,
        emptyBookingForm,
        formFromEvent,
    }
    "src/components/route-loading-bar" --> "src/components/route-loading-bar-portal" {
        RouteLoadingBar,
    }
    "src/components/language-provider" --> "src/app/(calendar)/upcoming-sidebar" { useLanguage }
    "src/components/sidebar-resize-boundary" --> "src/app/(calendar)/upcoming-sidebar" {
        SidebarResizeBoundary,
    }
    "src/components/sidebar-state" --> "src/app/(calendar)/upcoming-sidebar" { useSidebar }
    src.lib.auth.client --> "src/app/(calendar)/upcoming-sidebar" { authFetch }
    src.lib.calendar.colors --> "src/app/(calendar)/upcoming-sidebar" { normalizeCalendarColor }
    "src/app/(calendar)/calendar/types.d" --> "src/app/(calendar)/upcoming-sidebar" {
        CalendarEvent,
    }
    "src/app/(calendar)/calendar/utils" --> "src/app/(calendar)/upcoming-sidebar" {
        CalendarOverridesInput,
        UPCOMING_BATCH_SIZE,
        addDays,
        expandCalendarEvents,
        formatEventRange,
        groupUpcomingEvents,
        startOfDay,
        takeUpcomingGroups,
        toCalendarOverrides,
    }
    "src/app/(calendar)/upcoming-sidebar-types.d" --> "src/app/(calendar)/upcoming-sidebar" {
        UpcomingSidebarProps,
    }
    src.lib.i18n.utils --> "src/app/(calendar)/calendar/utils" { Translator, defaultTranslator }
    "src/app/(calendar)/calendar/types.d" --> "src/app/(calendar)/calendar/utils" {
        CalendarEvent,
        CalendarEventTimes,
        EventGroup,
        EventResizeEdge,
    }
    "src/lib/folders/types.d" --> "src/app/(calendar)/calendar/utils" { FolderColor }
    "src/lib/calendar/types.d" --> "src/app/(calendar)/calendar/utils" { CalendarRepeat }
    src.lib.calendar.recurrence --> "src/app/(calendar)/calendar/utils" {
        parseCalendarRepeatDays,
        parseExcludedOccurrences,
    }
    src.lib.time.utils --> "src/app/(calendar)/calendar/utils" {
        dateFromZonedFields,
        formatUserDate,
        formatUserDateTimeLocal,
        getDisplayLocale,
        getUserTimeZone,
        parseUserDateTimeLocal,
        zonedDateFields,
    }
    "src/components/sidebar-header" --> "src/app/(calendar)/calendar-logo-block" { SidebarHeader }
    "src/components/sidebar-state" --> "src/app/(calendar)/calendar-logo-block" { useSidebar }
    "src/components/sidebar-header" --> "src/app/(calendar)/calendar-mobile-upcoming" {
        SidebarHeader,
    }
    "src/components/sidebar-state" --> "src/app/(calendar)/calendar-mobile-upcoming" { useSidebar }
    "src/app/(calendar)/upcoming-sidebar" --> "src/app/(calendar)/calendar-mobile-upcoming" {
        UpcomingSidebar,
    }
    "src/components/language-provider" --> "src/app/(calendar)/calendar/day-events" { useLanguage }
    src.lib.calendar.colors --> "src/app/(calendar)/calendar/day-events" { normalizeCalendarColor }
    "src/app/(calendar)/calendar/utils" --> "src/app/(calendar)/calendar/day-events" {
        EVENT_COLOR_CLASSES,
        PAST_EVENT_COLOR_CLASSES,
        PENDING_EVENT_CLASSES,
        addDays,
        dateKey,
        eventPosition,
        formatEventRange,
        isPendingInvite,
    }
    "src/app/(calendar)/calendar/types.d" --> "src/app/(calendar)/calendar/day-events" {
        CalendarEvent,
        EventResizeEdge,
    }
    "src/app/(calendar)/calendar/day-events-types.d" --> "src/app/(calendar)/calendar/day-events" {
        DayEventsProps,
    }
    "src/components/language-provider" --> "src/app/(calendar)/calendar/invite-response-dialog" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(calendar)/calendar/invite-response-dialog" { Button }
    src.components.ui.dialog --> "src/app/(calendar)/calendar/invite-response-dialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.lib.auth.client --> "src/app/(calendar)/calendar/invite-response-dialog" { authFetch }
    "src/app/(calendar)/calendar/utils" --> "src/app/(calendar)/calendar/invite-response-dialog" {
        formatEventRange,
    }
    "src/app/(calendar)/calendar/types.d" --> "src/app/(calendar)/calendar/invite-response-dialog" {
        CalendarEvent,
    }
    "src/components/language-provider" --> "src/app/(calendar)/calendar/month-grid" { useLanguage }
    src.lib.calendar.colors --> "src/app/(calendar)/calendar/month-grid" { normalizeCalendarColor }
    src.lib.time.utils --> "src/app/(calendar)/calendar/month-grid" { formatUserDate }
    "src/app/(calendar)/calendar/utils" --> "src/app/(calendar)/calendar/month-grid" {
        EVENT_COLOR_CLASSES,
        PAST_EVENT_COLOR_CLASSES,
        PENDING_EVENT_CLASSES,
        addDays,
        dateKey,
        formatEventRange,
        isPendingInvite,
        monthGridDates,
    }
    "src/app/(calendar)/calendar/types.d" --> "src/app/(calendar)/calendar/month-grid" {
        CalendarEvent,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(calendar)/calendar/page" { confirmDestructive }
    src.components.icons --> "src/app/(calendar)/calendar/page" {
        AlignLeft,
        Bell,
        CalendarPlus2,
        Check,
        ChevronDown,
        ChevronLeft,
        ChevronRight,
        Clock3,
        MapPin,
        Palette,
        Plus,
        Repeat2,
        Trash2,
        UsersRound,
        X,
    }
    src.components.ui.button --> "src/app/(calendar)/calendar/page" { Button }
    src.components.ui.input --> "src/app/(calendar)/calendar/page" { Input }
    src.components.ui.textarea --> "src/app/(calendar)/calendar/page" { Textarea }
    "src/components/route-loading-bar-portal" --> "src/app/(calendar)/calendar/page" {
        RouteLoadingBarPortal,
    }
    src.lib.auth.client --> "src/app/(calendar)/calendar/page" { authFetch }
    src.lib.time.utils --> "src/app/(calendar)/calendar/page" {
        formatUserDate,
        getUserTimeZone,
        parseUserDateTimeLocal,
    }
    src.lib.calendar.colors --> "src/app/(calendar)/calendar/page" { normalizeCalendarColor }
    "src/lib/calendar/reminder-utils" --> "src/app/(calendar)/calendar/page" {
        REMINDER_MINUTE_OPTIONS,
    }
    src.lib.calendar.recurrence --> "src/app/(calendar)/calendar/page" {
        DEFAULT_REPEAT_DAYS,
        parseCalendarRepeatDays,
    }
    src.lib.folders.colors --> "src/app/(calendar)/calendar/page" {
        DEFAULT_FOLDER_COLOR,
        FOLDER_COLOR_OPTIONS,
    }
    "src/lib/i18n/types.d" --> "src/app/(calendar)/calendar/page" { TranslationKey }
    "src/lib/calendar/types.d" --> "src/app/(calendar)/calendar/page" { CalendarRepeat }
    "src/components/language-provider" --> "src/app/(calendar)/calendar/page" { useLanguage }
    "src/lib/folders/color-keys" --> "src/app/(calendar)/calendar/page" { folderColorKeys }
    "src/components/mailbox-provider" --> "src/app/(calendar)/calendar/page" { useSelectedMailbox }
    "src/components/sidebar-state" --> "src/app/(calendar)/calendar/page" { useSidebar }
    "src/app/(calendar)/upcoming-sidebar" --> "src/app/(calendar)/calendar/page" { UpcomingSidebar }
    "src/app/(calendar)/calendar/day-events" --> "src/app/(calendar)/calendar/page" { DayEvents }
    "src/app/(calendar)/calendar/month-grid" --> "src/app/(calendar)/calendar/page" { MonthGrid }
    "src/app/(calendar)/calendar/subscribe-dialog" --> "src/app/(calendar)/calendar/page" {
        CalendarSubscribeDialog,
    }
    "src/app/(calendar)/calendar/invite-response-dialog" --> "src/app/(calendar)/calendar/page" {
        InviteResponseDialog,
    }
    "src/app/(calendar)/calendar/types.d" --> "src/app/(calendar)/calendar/page" {
        CalendarEvent,
        CalendarView,
        EventDragPreview,
        EventResizeEdge,
        EventResizeSession,
    }
    "src/app/(calendar)/calendar/utils" --> "src/app/(calendar)/calendar/page" {
        CALENDAR_END_HOUR,
        CALENDAR_HOUR_HEIGHT,
        CALENDAR_START_HOUR,
        CalendarOccurrenceOverride,
        CalendarOccurrenceResponse,
        CalendarOverridesInput,
        EVENT_COLOR_CLASSES,
        PAST_EVENT_COLOR_CLASSES,
        WEEKDAY_OPTIONS,
        addDays,
        addMonths,
        calendarAnchorDay,
        currentTimePosition,
        dateKey,
        defaultCalendarStart,
        dropStartForPosition,
        eventEndAfterMinutes,
        eventPosition,
        expandCalendarEvents,
        formatEventRange,
        formatHour,
        formatLocalDateTime,
        isPendingInvite,
        monthGridDates,
        rescheduleCalendarOccurrence,
        resizeEventTimes,
        startOfDay,
        startOfMonth,
        startOfWeek,
        toCalendarOverrides,
    }
    "src/components/dialog-frame" --> "src/app/(calendar)/calendar/page" { DialogFrame }
    src.components.ui.select --> "src/app/(calendar)/calendar/page" { Select }
    src.components.icons --> "src/app/(calendar)/calendar/subscribe-dialog" { Copy }
    "src/components/language-provider" --> "src/app/(calendar)/calendar/subscribe-dialog" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(calendar)/calendar/subscribe-dialog" { Button }
    src.components.ui.dialog --> "src/app/(calendar)/calendar/subscribe-dialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.lib.auth.client --> "src/app/(calendar)/calendar/subscribe-dialog" { authFetch }
    "src/components/use-dialog-focus" --> "src/components/dialog-frame" { useDialogFocus }
    "src/components/skip-to-content" --> "src/app/(calendar)/layout" { SkipToContent }
    src.components.icons --> "src/app/(calendar)/layout" { Sparkles }
    "src/components/language-provider" --> "src/app/(calendar)/layout" { useLanguage }
    "src/components/agent/agent-panel" --> "src/app/(calendar)/layout" { AgentPanel }
    "src/components/agent/assistant-open-state" --> "src/app/(calendar)/layout" {
        AssistantOpenContext,
    }
    "src/components/auth/auth-guard" --> "src/app/(calendar)/layout" { AuthGuard }
    "src/components/compose/compose-context" --> "src/app/(calendar)/layout" { ComposeProvider }
    "src/components/compose/floating-composer" --> "src/app/(calendar)/layout" { FloatingComposer }
    "src/components/license-indicator" --> "src/app/(calendar)/layout" { LicenseIndicator }
    "src/components/mail-search/mail-search-context" --> "src/app/(calendar)/layout" {
        MailSearchProvider,
    }
    "src/components/mailbox-provider" --> "src/app/(calendar)/layout" { MailboxProvider }
    "src/components/mailbox-selector" --> "src/app/(calendar)/layout" { MailboxSelector }
    "src/components/sidebar-aside" --> "src/app/(calendar)/layout" {
        MobileMenuButton,
        SidebarAside,
    }
    "src/components/sidebar-state" --> "src/app/(calendar)/layout" { SidebarProvider }
    src.components.shortcuts.index --> "src/app/(calendar)/layout" { ShortcutsProvider }
    src.components.ui.button --> "src/app/(calendar)/layout" { Button }
    "src/app/(calendar)/calendar-logo-block" --> "src/app/(calendar)/layout" { CalendarLogoBlock }
    "src/app/(calendar)/calendar-mobile-upcoming" --> "src/app/(calendar)/layout" {
        CalendarMobileUpcoming,
    }
    "src/app/(dashboard)/dashboard-state" --> "src/app/(calendar)/layout" { useDashboardState }
    "src/app/(dashboard)/use-assistant-availability" --> "src/app/(calendar)/layout" {
        useAssistantAvailability,
    }
    "src/components/route-title" --> "src/app/(calendar)/layout" { RouteTitle }
    src.components.ui.select --> "src/app/(calendar)/layout" { Select }
    src.components.icons --> "src/components/agent/agent-panel" {
        ArrowLeft,
        FileText,
        ListChecks,
        LoaderCircle,
        Maximize2,
        Minimize2,
        Pause,
        PauseCircle,
        PenLine,
        Plus,
        Send,
        Settings2,
        Sparkles,
        Square,
        Trash2,
        X,
    }
    "src/components/language-provider" --> "src/components/agent/agent-panel" { useLanguage }
    src.lib.auth.client --> "src/components/agent/agent-panel" { authFetch }
    "src/lib/messages/detail-cache" --> "src/components/agent/agent-panel" {
        fetchCachedMessageDetail,
    }
    src.lib.time.utils --> "src/components/agent/agent-panel" { getUserTimeZone }
    "src/components/mailbox-provider" --> "src/components/agent/agent-panel" { useSelectedMailbox }
    "src/components/compose/compose-context" --> "src/components/agent/agent-panel" { useCompose }
    src.components.ui.button --> "src/components/agent/agent-panel" { Button }
    src.components.ui.switch --> "src/components/agent/agent-panel" { Switch }
    "src/components/agent/agent-turn" --> "src/components/agent/agent-panel" { AgentTurnView }
    "src/components/agent/conversation-skeleton" --> "src/components/agent/agent-panel" {
        ConversationSkeleton,
    }
    "src/components/agent/queued-messages" --> "src/components/agent/agent-panel" {
        QueuedAgentMessages,
    }
    "src/components/agent/send-review" --> "src/components/agent/agent-panel" { SendReview }
    "src/components/agent/send-review-types.d" --> "src/components/agent/agent-panel" {
        ReviewSnapshot,
    }
    "src/components/agent/client-actions" --> "src/components/agent/agent-panel" {
        approveAgentAction,
        requestDraftReview,
    }
    "src/components/agent/types.d" --> "src/components/agent/agent-panel" {
        AgentConversation,
        AgentConversationsResponse,
        AgentErrorResponse,
        AgentEvent,
        AgentHistoryResponse,
        AgentJob,
        AgentJobsResponse,
        AgentMessage,
        AgentPanelProps,
        AgentPanelView,
        AgentSettings,
        AgentSettingsResponse,
        QueuedAgentMessage,
    }
    src.components.agent.utils --> "src/components/agent/agent-panel" {
        activeAgentTool,
        activeAgentToolLabel,
        appendAgentReasoning,
        consumeAgentStream,
        editQueuedAgentMessage,
        enqueueAgentMessage,
        groupAgentMessages,
        isAgentScrollAtBottom,
        markAgentDraftSent,
        normalizeAgentHistory,
        readAgentConversationId,
        removeQueuedAgentMessage,
        resizeAgentInput,
        saveAgentConversationId,
        shouldSubmitAgentInput,
        steerQueuedAgentMessage,
        uniqueAgentDraftActions,
    }
    src.components.ui.select --> "src/components/agent/agent-panel" { Select }
    src.components.icons --> "src/components/agent/agent-turn" { ChevronDown, Clock3 }
    "src/components/language-provider" --> "src/components/agent/agent-turn" { useLanguage }
    "src/components/agent/types.d" --> "src/components/agent/agent-turn" { AgentTurnProps }
    src.components.agent.utils --> "src/components/agent/agent-turn" {
        agentDraftIdFromHref,
        formatAgentDuration,
    }
    "src/components/agent/tool-activity" --> "src/components/agent/agent-turn" {
        AgentDraftActions,
        AgentPendingActions,
        AgentToolActivity,
    }
    src.components.icons --> "src/components/agent/tool-activity" { ChevronLeft, Wrench }
    "src/components/language-provider" --> "src/components/agent/tool-activity" { useLanguage }
    "src/components/agent/types.d" --> "src/components/agent/tool-activity" {
        AgentDraftAction,
        AgentEmailReference,
        AgentMessage,
        AgentTurnProps,
    }
    src.components.agent.utils --> "src/components/agent/tool-activity" {
        agentActionProposal,
        agentToolLabel,
        draftFromToolContent,
        parseAgentToolContent,
    }
    "src/components/agent/email-link" --> "src/components/agent/tool-activity" { AgentEmailLink }
    "src/components/agent/types.d" --> "src/components/agent/email-link" { AgentEmailLinkProps }
    src.components.agent.utils --> "src/components/agent/email-link" {
        agentDraftIdForEmail,
        agentEmailHref,
    }
    "src/components/language-provider" --> "src/components/agent/conversation-skeleton" {
        useLanguage,
    }
    src.components.ui.skeleton --> "src/components/agent/conversation-skeleton" { Skeleton }
    src.components.icons --> "src/components/agent/queued-messages" {
        CornerDownRight,
        Pencil,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/agent/queued-messages" { useLanguage }
    "src/components/agent/types.d" --> "src/components/agent/queued-messages" {
        QueuedAgentMessagesProps,
    }
    src.lib.auth.client --> "src/components/agent/client-actions" { authFetch }
    "src/components/agent/send-review-types.d" --> "src/components/agent/client-actions" {
        ReviewSnapshot,
    }
    "src/hooks/use-current-user" --> "src/app/(dashboard)/dashboard-state" { fetchCurrentUser }
    "src/app/(dashboard)/dashboard-state-utils" --> "src/app/(dashboard)/dashboard-state" {
        readInitialAssistantPanelState,
        saveAssistantPanelState,
    }
    src.lib.auth.client --> "src/app/(dashboard)/use-assistant-availability" {
        AUTH_SESSION_CHANGED_EVENT,
        authFetch,
    }
    "src/lib/agent/availability-client" --> "src/app/(dashboard)/use-assistant-availability" {
        readInitialAssistantAvailability,
        saveAssistantAvailability,
    }
    "src/app/(dashboard)/assistant-availability-types.d" --> "src/app/(dashboard)/use-assistant-availability" {
        AssistantAvailabilityResponse,
    }
    "src/components/language-provider" --> "src/app/(dashboard)/agent/calendar-review/page" {
        useLanguage,
    }
    src.components.ui.button --> "src/app/(dashboard)/agent/calendar-review/page" { Button }
    src.lib.auth.client --> "src/app/(dashboard)/agent/calendar-review/page" { authFetch }
    "src/components/language-provider" --> "src/app/(dashboard)/agent/review/[id]/page" {
        useLanguage,
    }
    src.lib.auth.client --> "src/app/(dashboard)/agent/review/[id]/page" { authFetch }
    "src/components/agent/send-review" --> "src/app/(dashboard)/agent/review/[id]/page" {
        SendReview,
    }
    "src/components/agent/send-review-types.d" --> "src/app/(dashboard)/agent/review/[id]/page" {
        AgentReviewResponse,
    }
    "src/app/(dashboard)/inbox/[messageId]/page" --> "src/app/(dashboard)/archived/[messageId]/page" {
        default,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        confirmDestructive,
    }
    src.lib.auth.client --> "src/app/(dashboard)/inbox/[messageId]/page" { authFetch }
    src.components.icons --> "src/app/(dashboard)/inbox/[messageId]/page" {
        ArrowDownToLine,
        Cloud,
        ExternalLink,
    }
    "src/components/language-provider" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useLanguage,
    }
    src.lib.time.utils --> "src/app/(dashboard)/inbox/[messageId]/page" { formatUserDate }
    "src/components/mark-read" --> "src/app/(dashboard)/inbox/[messageId]/page" { markMessageRead }
    "src/components/mailbox-provider" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useSelectedMailbox,
    }
    "src/components/contacts/contact-details" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        ContactDetailsTrigger,
    }
    "src/components/contacts/contact-avatar" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        ContactAvatar,
    }
    "src/components/message-actions/message-actions" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageActions,
    }
    "src/components/message-attachment-viewer" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageAttachmentViewer,
    }
    "src/components/message-attachment-card" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageAttachmentCard,
    }
    "src/components/message-invite-card" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageInviteCard,
    }
    "src/components/page-skeletons" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageDetailSkeleton,
    }
    src.components.ui.skeleton --> "src/app/(dashboard)/inbox/[messageId]/page" { Skeleton }
    src.components.ui.button --> "src/app/(dashboard)/inbox/[messageId]/page" { Button }
    "src/components/page-loading" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        usePageLoading,
    }
    "src/components/previous-message" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        PreviousMessage,
    }
    "src/components/messages/conversation-thread" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        ConversationThread,
    }
    "src/components/messages/conversation-thread-utils" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        getConversationSender,
    }
    "src/components/messages/conversation-notes" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        ConversationNotes,
    }
    "src/components/messages/conversation-notes-context" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        ConversationNotesProvider,
    }
    "src/components/messages/message-detail-navigation" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageDetailNavigation,
    }
    "src/components/messages/message-reading-header-button" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageReadingHeaderButton,
    }
    "src/components/messages/scheduled-send-banner" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        ScheduledSendBanner,
    }
    "src/components/messages/scheduled-send-utils" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        formatScheduledSendTime,
    }
    "src/components/messages/quoted-email-toggle" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        QuotedEmailToggle,
    }
    "src/components/messages/thread-message-actions" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        ThreadMessageActions,
    }
    "src/components/messages/unsubscribe-button" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageUnsubscribeButton,
    }
    "src/components/messages/message-details-panel" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageDetailsPanel,
    }
    "src/components/messages/sender-check-notice" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        SenderCheckNotice,
    }
    "src/components/messages/use-message-thread" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useMessageThread,
    }
    "src/components/messages/use-latest-messages-first" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useLatestMessagesFirst,
    }
    "src/components/messages/message-list-visibility" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useMessageListVisibility,
    }
    "src/lib/messages/field-store" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        subscribePendingOverlay,
    }
    src.lib.email.address --> "src/app/(dashboard)/inbox/[messageId]/page" {
        getEmailAddress,
        splitEmailAddressList,
    }
    "src/lib/calendar/invite-attachment" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        findInviteAttachment,
    }
    "src/lib/email/recipient-display" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        RecipientAddressStyle,
        formatRecipientAddressList,
    }
    "src/components/messages/recipient-list" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        RecipientList,
    }
    "src/components/messages/use-show-full-recipient-addresses" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useShowFullRecipientAddresses,
    }
    "src/app/(dashboard)/inbox/[messageId]/types.d" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MessageAttachment,
        MessageDetailResponse,
    }
    "src/app/(dashboard)/inbox/[messageId]/utils" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        fetchMessageDetail,
        fetchMessageMetadata,
        getCachedMessageDetailForDisplay,
        getMessageBodyDisplay,
        getMessageHeaderParties,
        getOwnAddressForMessage,
        resolveInlineAttachmentUrls,
    }
    "src/app/(dashboard)/inbox/[messageId]/cloud-attachment-utils" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        extractCloudAttachments,
    }
    "src/components/messages/email-html-renderer" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        EmailHtmlRenderer,
    }
    "src/components/messages/use-remote-content" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useRemoteContent,
    }
    "src/components/agent/assistant-open-state" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useAssistantOpen,
    }
    "src/app/(dashboard)/inbox/[messageId]/use-message-content-scroll" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useMessageContentScroll,
    }
    "src/components/messages/use-send-view-status" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useSendViewStatus,
    }
    "src/components/messages/mailing-list-banner" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        MailingListBanner,
    }
    "src/components/messages/use-mailing-list-banner" --> "src/app/(dashboard)/inbox/[messageId]/page" {
        useMailingListBanner,
    }
    src.lib.auth.client --> "src/components/mark-read" { authFetch }
    src.hooks.utils --> "src/components/mark-read" { markMessagesReadInCaches }
    "src/lib/messages/change-events" --> "src/components/mark-read" { dispatchMessagesChanged }
    "src/components/language-provider" --> "src/components/contacts/contact-details" { useLanguage }
    src.lib.time.utils --> "src/components/contacts/contact-details" { formatUserDate }
    src.components.ui.button --> "src/components/contacts/contact-details" { Button }
    src.components.ui.dialog --> "src/components/contacts/contact-details" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/contacts/contact-details" { Input }
    "src/components/contacts/contact-avatar-form" --> "src/components/contacts/contact-details" {
        ContactAvatarForm,
    }
    "src/components/contacts/contact-imported-details" --> "src/components/contacts/contact-details" {
        ContactImportedDetails,
    }
    src.components.ui.label --> "src/components/contacts/contact-details" { Label }
    "src/components/contacts/contact-details-types.d" --> "src/components/contacts/contact-details" {
        ContactDetailsRecord,
        ContactDetailsTriggerProps,
    }
    "src/components/contacts/contact-details-utils" --> "src/components/contacts/contact-details" {
        fetchContactDetails,
        updateContactName,
    }
    src.components.icons --> "src/components/contacts/contact-avatar-form" { Camera, LoaderCircle }
    "src/lib/contacts/avatar-client" --> "src/components/contacts/contact-avatar-form" {
        dispatchContactAvatarChanged,
    }
    src.lib.email.address --> "src/components/contacts/contact-avatar-form" {
        normalizeEmailAddress,
    }
    src.components.ui.input --> "src/components/contacts/contact-avatar-form" { Input }
    "src/components/language-provider" --> "src/components/contacts/contact-avatar-form" {
        useLanguage,
    }
    "src/components/contacts/contact-avatar" --> "src/components/contacts/contact-avatar-form" {
        ContactAvatar,
    }
    "src/components/contacts/contact-avatar-form-types.d" --> "src/components/contacts/contact-avatar-form" {
        ContactAvatarFormProps,
    }
    "src/components/contacts/contact-avatar-form-utils" --> "src/components/contacts/contact-avatar-form" {
        CONTACT_AVATAR_ACCEPT,
        removeContactAvatar,
        uploadContactAvatar,
        validateContactAvatar,
    }
    src.lib.auth.client --> "src/components/contacts/contact-avatar-form-utils" { authFetch }
    "src/lib/avatar-upload-client" --> "src/components/contacts/contact-avatar-form-utils" {
        MAX_SOURCE_AVATAR_SIZE,
        appendOptimizedAvatar,
    }
    "src/components/language-provider" --> "src/components/contacts/contact-imported-details" {
        useLanguage,
    }
    "src/lib/contacts/details-utils" --> "src/components/contacts/contact-imported-details" {
        formatBirthday,
    }
    "src/components/contacts/contact-details-types.d" --> "src/components/contacts/contact-imported-details" {
        ContactImportedDetailsProps,
    }
    src.lib.auth.client --> "src/components/contacts/contact-details-utils" { authFetch }
    src.lib.email.address --> "src/components/contacts/contact-details-utils" { getEmailAddress }
    "src/components/contacts/contact-details-types.d" --> "src/components/contacts/contact-details-utils" {
        ContactDetailsRecord,
        ContactDetailsResponse,
    }
    "src/components/ui/confirm-dialog" --> "src/components/message-actions/message-actions" {
        confirmDestructive,
    }
    src.components.icons --> "src/components/message-actions/message-actions" {
        Archive,
        ArchiveRestore,
        Ban,
        BellOff,
        Clock,
        FileCode2,
        Forward,
        Inbox,
        Mail,
        MailOpen,
        MoreVertical,
        Note,
        Reply,
        ReplyAll,
        ShieldAlert,
        ShieldCheck,
        Tag,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/message-actions/message-actions" {
        useLanguage,
    }
    "src/components/mailbox-provider" --> "src/components/message-actions/message-actions" {
        useSelectedMailbox,
    }
    "src/hooks/use-message-counts" --> "src/components/message-actions/message-actions" {
        useMessageCounts,
    }
    "src/lib/promotions/move-client" --> "src/components/message-actions/message-actions" {
        moveMessagesToCategory,
    }
    "src/lib/promotions/move-utils" --> "src/components/message-actions/message-actions" {
        canMoveCategory,
        moveLeavesFolder,
        moveTargetFor,
        readerFolderOf,
    }
    "src/components/compose/compose-context" --> "src/components/message-actions/message-actions" {
        useCompose,
    }
    "src/components/messages/message-source-dialog" --> "src/components/message-actions/message-actions" {
        MessageSourceDialog,
    }
    "src/components/messages/message-list-visibility" --> "src/components/message-actions/message-actions" {
        useMessageListVisibility,
    }
    "src/components/messages/message-detail-navigation" --> "src/components/message-actions/message-actions" {
        useAutoAdvance,
    }
    "src/components/messages/conversation-notes-context" --> "src/components/message-actions/message-actions" {
        useConversationNotes,
    }
    "src/components/message-actions/message-snooze-dialog" --> "src/components/message-actions/message-actions" {
        MessageSnoozeDialog,
    }
    "src/components/messages/unsubscribe-button-utils" --> "src/components/message-actions/message-actions" {
        requestUnsubscribe,
    }
    "src/components/message-actions/action-menu" --> "src/components/message-actions/message-actions" {
        MessageActionMenu,
        MessageActionMenuItem,
        MessageActionMenuLabel,
        MessageActionMenuSeparator,
    }
    "src/components/message-actions/action-overflow-utils" --> "src/components/message-actions/message-actions" {
        getVisibleActionCount,
    }
    src.components.shortcuts.index --> "src/components/message-actions/message-actions" {
        useHotkeys,
        useShortcuts,
    }
    src.components.ui.button --> "src/components/message-actions/message-actions" { Button }
    src.components.ui.tooltip --> "src/components/message-actions/message-actions" { Tooltip }
    src.lib.utils --> "src/components/message-actions/message-actions" { cn }
    "src/app/api/messages/bulk/types.d" --> "src/components/message-actions/message-actions" {
        BulkMessageAction,
    }
    "src/components/message-actions/types.d" --> "src/components/message-actions/message-actions" {
        MessageActionsProps,
        ReplyMode,
    }
    "src/lib/messages/permanent-delete-utils" --> "src/components/message-actions/message-actions" {
        PartialDeleteError,
        getPermanentDeleteConfirmText,
        supportsPermanentDelete,
    }
    "src/components/message-actions/utils" --> "src/components/message-actions/message-actions" {
        blockMessageContact,
        canBlockSenderDomain,
        confirmTrashWithoutUnsubscribe,
        createForwardDraft,
        createReplyDraft,
        createTrashSenderRule,
        getBlockErrorKey,
        getMessageActionRedirect,
        getMessageBackHref,
        getMoveMessageActions,
        getReplyRecipients,
        getReplyThreading,
        getSenderDomain,
        hasAdditionalRecipients,
        openUnsubscribeUrl,
        runSingleMessageAction,
    }
    "src/components/messages/promotion-toast-store" --> "src/lib/promotions/move-client" {
        showPromotionToast,
        updatePromotionToast,
    }
    src.lib.auth.client --> "src/lib/promotions/move-client" { authFetch }
    "src/lib/messages/detail-cache" --> "src/lib/promotions/move-client" {
        invalidateCachedMessageDetails,
    }
    "src/lib/messages/change-events" --> "src/lib/promotions/move-client" {
        dispatchMessagesChanged,
    }
    "src/lib/promotions/move-utils" --> "src/lib/promotions/move-client" {
        MoveSummary,
        MoveTarget,
        canOfferAlways,
        moveToastCopy,
        runLimited,
        senderResultCopy,
        summarizeMoves,
    }
    "src/lib/promotions/move-utils" --> "src/components/messages/promotion-toast-store" {
        CopyDescriptor,
        MoveTarget,
    }
    "src/lib/i18n/types.d" --> "src/lib/promotions/move-utils" { PluralKey, TranslationKey }
    src.components.icons --> "src/components/messages/message-source-dialog" {
        CheckCircle2,
        Copy,
        Download,
        LoaderCircle,
    }
    "src/components/language-provider" --> "src/components/messages/message-source-dialog" {
        useLanguage,
    }
    src.components.ui.dialog --> "src/components/messages/message-source-dialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.button --> "src/components/messages/message-source-dialog" { Button }
    "src/components/messages/message-source-dialog-types.d" --> "src/components/messages/message-source-dialog" {
        MessageSourceDialogProps,
    }
    "src/components/messages/message-source-utils" --> "src/components/messages/message-source-dialog" {
        copyMessageSource,
        downloadMessageSource,
        fetchMessageSource,
        summarizeMessageSource,
    }
    src.lib.auth.client --> "src/components/messages/message-source-utils" { authFetch }
    src.lib.time.utils --> "src/components/messages/message-source-utils" { formatUserDate }
    "src/components/messages/message-source-types.d" --> "src/components/messages/message-source-utils" {
        AuthenticationSummary,
        MessageSourceSummary,
    }
    "src/components/messages/types.d" --> "src/components/messages/message-list-visibility" {
        MessageListVisibility,
    }
    src.components.icons --> "src/components/messages/message-detail-navigation" {
        ChevronLeft,
        ChevronRight,
    }
    "src/components/language-provider" --> "src/components/messages/message-detail-navigation" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/messages/message-detail-navigation" { Button }
    src.components.ui.tooltip --> "src/components/messages/message-detail-navigation" { Tooltip }
    "src/components/mailbox-provider" --> "src/components/messages/message-detail-navigation" {
        useSelectedMailbox,
    }
    src.lib.auth.client --> "src/components/messages/message-detail-navigation" { authFetch }
    "src/lib/messages/detail-cache" --> "src/components/messages/message-detail-navigation" {
        fetchCachedMessageDetail,
        getCachedMessageDetail,
    }
    "src/lib/calendar/invite-cache" --> "src/components/messages/message-detail-navigation" {
        fetchInviteCard,
        getCachedInviteCard,
    }
    "src/lib/calendar/invite-attachment" --> "src/components/messages/message-detail-navigation" {
        findInviteAttachment,
    }
    src.lib.navigation.prefetch --> "src/components/messages/message-detail-navigation" {
        FULL_ROUTE_PREFETCH,
    }
    "src/lib/messages/detail-cache-types.d" --> "src/components/messages/message-detail-navigation" {
        CachedMessageDetail,
    }
    "src/app/api/messages/navigation/types.d" --> "src/components/messages/message-detail-navigation" {
        MessageNavigationResponse,
    }
    "src/components/messages/message-detail-navigation-types.d" --> "src/components/messages/message-detail-navigation" {
        MessageDetailNavigationContextValue,
        MessageDetailNavigationProps,
        MessageDetailNavigationProviderProps,
        MessageDetailNavigationSnapshot,
        OpenedUnreadMessages,
    }
    "src/components/messages/message-detail-navigation-utils" --> "src/components/messages/message-detail-navigation" {
        getAutoAdvanceId,
        getMessageDetailNavigationState,
        takeOpenedUnreadMessage,
    }
    "src/components/messages/use-auto-advance" --> "src/components/messages/message-detail-navigation" {
        useAutoAdvanceEnabled,
    }
    "src/components/messages/use-conversation-view" --> "src/components/messages/message-detail-navigation" {
        useConversationView,
    }
    src.lib.auth.client --> "src/lib/calendar/invite-cache" {
        AUTH_SESSION_CHANGED_EVENT,
        authFetch,
    }
    "src/lib/calendar/invite-types.d" --> "src/lib/calendar/invite-cache" {
        InviteCardData,
        InviteResponse,
        InviteView,
    }
    "src/app/api/messages/navigation/types.d" --> "src/components/messages/message-detail-navigation-utils" {
        MessageNavigationEntry,
    }
    "src/components/messages/message-detail-navigation-types.d" --> "src/components/messages/message-detail-navigation-utils" {
        MessageDetailNavigationState,
    }
    src.lib.auth.client --> "src/components/messages/conversation-notes-context" { authFetch }
    "src/lib/notes/types.d" --> "src/components/messages/conversation-notes-context" {
        ConversationNote,
    }
    "src/components/messages/conversation-notes-types.d" --> "src/components/messages/conversation-notes-context" {
        ConversationNotesProviderProps,
        ConversationNotesState,
    }
    "src/components/messages/message-list-row-actions-utils" --> "src/components/message-actions/message-snooze-dialog" {
        getSnoozePresets,
        snoozeMessage,
    }
    "src/components/language-provider" --> "src/components/message-actions/message-snooze-dialog" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/message-actions/message-snooze-dialog" { Button }
    src.components.ui.dialog --> "src/components/message-actions/message-snooze-dialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/message-actions/message-snooze-dialog" { Input }
    "src/components/message-actions/types.d" --> "src/components/message-actions/message-snooze-dialog" {
        MessageSnoozeDialogProps,
    }
    src.lib.time.utils --> "src/components/message-actions/message-snooze-dialog" {
        getUserTimeZone,
    }
    "src/lib/i18n/types.d" --> "src/components/messages/message-list-row-actions-utils" {
        TranslationKey,
    }
    src.lib.auth.client --> "src/components/messages/message-list-row-actions-utils" { authFetch }
    src.lib.messages.actions.client --> "src/components/messages/message-list-row-actions-utils" {
        performMessageAction,
    }
    "src/hooks/types.d" --> "src/components/messages/message-list-row-actions-utils" {
        MessageCountsDelta,
    }
    src.lib.time.utils --> "src/components/messages/message-list-row-actions-utils" {
        dateFromZonedFields,
        formatUserDateTimeLocal,
        getUserTimeZone,
        parseUserDateTimeLocal,
        zonedDateFields,
    }
    src.lib.auth.client --> src.lib.messages.actions.client { authFetch }
    "src/lib/messages/change-events" --> src.lib.messages.actions.client {
        MessageFieldPatch,
        MessageMembershipState,
        dispatchMessagesChanged,
    }
    "src/lib/messages/detail-cache" --> src.lib.messages.actions.client {
        CachedMessageStatePatch,
        invalidateCachedMessageDetails,
        invalidateMessageDetailRequests,
        patchCachedMessageState,
    }
    "src/lib/messages/field-store" --> src.lib.messages.actions.client {
        KnownMessageFields,
        PendingOverlayMessage,
        ThreadUnreadTarget,
        captureMessageFields,
        captureThreadUnread,
        clearPendingOverlay,
        forgetMessageFields,
        getPendingThreadTargets,
        getThreadRowIdsForMessages,
        getThreadUnreadTargets,
        invalidateThreadUnreadTargets,
        rememberThreadUnreadTargets,
        setPendingOverlay,
    }
    "src/lib/messages/membership-store" --> src.lib.messages.actions.client {
        MembershipPatch,
        captureVisibleMembership,
        clearMembershipOverlay,
        clearRestoredRows,
        forgetRemovedRows,
        getKnownMembershipRow,
        hasRemovedRow,
        isGroupedMember,
        markRemovedRowsRestored,
        setMembershipOverlay,
        updateRemovedRows,
    }
    "src/lib/messages/list-membership" --> src.lib.messages.actions.client {
        MessageMembershipFields,
    }
    src.hooks.utils --> src.lib.messages.actions.client {
        clearMessageListCache,
        invalidateMessageListRequests,
        patchMessageFieldsInCaches,
    }
    "src/components/messages/message-thread-cache" --> src.lib.messages.actions.client {
        clearMessageThreadCache,
        invalidateMessageThreadRequests,
    }
    src.lib.messages.actions.definitions --> src.lib.messages.actions.client {
        getChangedStateFields,
        getMessageActionPatch,
    }
    src.lib.messages.actions.executor --> src.lib.messages.actions.client {
        MessageActionExecutor,
        MessageActionExecutorHooks,
        MessageActionHookContext,
        MessageActionHookOptions,
        MessageActionRequestError,
        MessageActionTransport,
        getChangedRecords,
        hasMembershipChange,
    }
    "src/lib/messages/actions/undo-store" --> src.lib.messages.actions.client {
        UndoToastEntry,
        showUndoToast,
    }
    "src/lib/messages/actions/types.d" --> src.lib.messages.actions.client {
        MessageActionInput,
        MessageActionRecord,
        MessageActionRequestOptions,
        MessageActionResponse,
        MessageActionTransportBody,
        MessageStateSnapshot,
        ReversibleMessageAction,
        UndoMessageActionResponse,
    }
    src.lib.auth.client --> "src/components/messages/message-thread-cache" {
        AUTH_SESSION_CHANGED_EVENT,
        authFetch,
    }
    "src/lib/messages/change-events" --> "src/components/messages/message-thread-cache" {
        getMessagesChangedDetail,
    }
    "src/lib/messages/field-store" --> "src/components/messages/message-thread-cache" {
        applyPendingToMessages,
        rememberMessageFields,
        rememberMessageRows,
    }
    "src/lib/messages/membership-store" --> "src/components/messages/message-thread-cache" {
        rememberMembershipRows,
    }
    "src/hooks/types.d" --> "src/components/messages/message-thread-cache" {
        ThreadMessage,
        ThreadResponse,
    }
    "src/lib/messages/actions/types.d" --> src.lib.messages.actions.definitions {
        MessageActionSkipReason,
        MessageStateField,
        MessageStateSnapshot,
        ReversibleMessageAction,
    }
    src.lib.messages.actions.definitions --> src.lib.messages.actions.executor {
        getChangedStateFields,
        recordHasChanges,
    }
    "src/lib/messages/field-store" --> src.lib.messages.actions.executor {
        KnownMessageFields,
        getConversationLockKeys,
    }
    "src/lib/messages/list-membership" --> src.lib.messages.actions.executor {
        MessageMembershipFields,
    }
    "src/lib/messages/actions/types.d" --> src.lib.messages.actions.executor {
        MessageActionInput,
        MessageActionRecord,
        MessageActionResponse,
        MessageActionTransportBody,
        UndoMessageActionResponse,
    }
    src.lib.auth.client --> "src/lib/messages/actions/undo-store" { AUTH_SESSION_CHANGED_EVENT }
    "src/lib/messages/actions/types.d" --> "src/lib/messages/actions/undo-store" {
        MessageActionRecord,
        MessageActionSkipReason,
        ReversibleMessageAction,
    }
    src.lib.auth.client --> "src/components/messages/unsubscribe-button-utils" { authFetch }
    "src/app/api/messages/[messageId]/unsubscribe/types.d" --> "src/components/messages/unsubscribe-button-utils" {
        UnsubscribeActionResult,
        UnsubscribePayload,
        UnsubscribePreviewResult,
        UnsubscribeResult,
    }
    src.components.ui.tooltip --> "src/components/message-actions/action-menu" { Tooltip }
    src.lib.utils --> "src/components/message-actions/action-menu" { cn }
    "src/app/api/messages/bulk/types.d" --> "src/lib/messages/permanent-delete-utils" {
        PermanentDeleteFolder,
    }
    src.lib.i18n.utils --> "src/lib/messages/permanent-delete-utils" {
        Translator,
        defaultTranslator,
    }
    "src/app/api/messages/bulk/types.d" --> "src/components/message-actions/utils" {
        BulkMessageAction,
    }
    "src/components/ui/confirm-dialog" --> "src/components/message-actions/utils" {
        confirmDestructive,
    }
    src.lib.auth.client --> "src/components/message-actions/utils" { authFetch }
    "src/lib/messages/permanent-delete-utils" --> "src/components/message-actions/utils" {
        throwIfDeleteSkipped,
    }
    "src/lib/messages/change-events" --> "src/components/message-actions/utils" {
        dispatchMessagesChanged,
    }
    src.lib.messages.actions.client --> "src/components/message-actions/utils" {
        performMessageAction,
    }
    src.lib.messages.actions.definitions --> "src/components/message-actions/utils" {
        isReversibleMessageAction,
    }
    src.lib.email.address --> "src/components/message-actions/utils" {
        getEmailAddress,
        normalizeEmailAddress,
        splitEmailAddressList,
    }
    "src/lib/spam/domain-utils" --> "src/components/message-actions/utils" { isSharedMailDomain }
    "src/lib/email/reply-content-utils" --> "src/components/message-actions/utils" {
        getLatestEmailContent,
    }
    src.lib.time.utils --> "src/components/message-actions/utils" { formatUserDate }
    "src/app/(dashboard)/inbox/[messageId]/email-html-sanitizer" --> "src/components/message-actions/utils" {
        sanitizeEmailHtml,
    }
    "src/components/compose/rich-text-utils" --> "src/components/message-actions/utils" {
        escapeHtml,
        htmlToPlainText,
        textToHtml,
        wrapQuotedHtml,
    }
    "src/components/message-actions/types.d" --> "src/components/message-actions/utils" {
        BlockMessageContactInput,
        ForwardDraftInput,
        MoveMessageActionItem,
        ReplyDraftInput,
        ReplyMode,
        ReplyRecipients,
        ReplyableMessage,
        TrashSenderRuleInput,
    }
    src.components.icons --> "src/components/message-actions/utils" {
        ArchiveIcon,
        Inbox,
        InboxIcon,
        ShieldAlertIcon,
        ShieldIcon,
        Trash2Icon,
        TrashIcon,
    }
    src.components.icons --> "src/components/message-attachment-viewer" {
        ArrowDownToLine,
        Check,
        FileWarning,
        HardDrive,
    }
    src.components.ui.button --> "src/components/message-attachment-viewer" { Button }
    src.components.ui.dialog --> "src/components/message-attachment-viewer" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    "src/components/language-provider" --> "src/components/message-attachment-viewer" {
        useLanguage,
    }
    "src/hooks/use-current-user" --> "src/components/message-attachment-viewer" { useCurrentUser }
    src.lib.auth.client --> "src/components/message-attachment-viewer" { authFetch }
    src.components.ui.skeleton --> "src/components/message-attachment-viewer" { Skeleton }
    "src/lib/email/attachment-risk" --> "src/components/message-attachment-viewer" {
        AttachmentRisk,
    }
    "src/components/message-attachment-viewer-types.d" --> "src/components/message-attachment-viewer" {
        MessageAttachmentViewerProps,
    }
    "src/components/message-attachment-viewer-utils" --> "src/components/message-attachment-viewer" {
        getAttachmentFileUrl,
        getAttachmentPreviewKind,
    }
    src.components.ui.checkbox --> "src/components/message-attachment-viewer" { Checkbox }
    "src/app/(dashboard)/inbox/[messageId]/types.d" --> "src/components/message-attachment-viewer-utils" {
        MessageAttachment,
    }
    "src/components/message-attachment-viewer-types.d" --> "src/components/message-attachment-viewer-utils" {
        AttachmentPreviewKind,
    }
    src.components.icons --> "src/components/message-attachment-card" { ArrowDownToLine, Play }
    "src/app/(dashboard)/inbox/[messageId]/utils" --> "src/components/message-attachment-card" {
        formatAttachmentSize,
    }
    "src/components/language-provider" --> "src/components/message-attachment-card" { useLanguage }
    "src/components/message-attachment-card-types.d" --> "src/components/message-attachment-card" {
        MessageAttachmentCardProps,
    }
    "src/components/message-attachment-viewer-utils" --> "src/components/message-attachment-card" {
        getAttachmentFileUrl,
    }
    "src/components/message-attachment-card-utils" --> "src/components/message-attachment-card" {
        getAttachmentVisual,
    }
    src.lib.auth.client --> "src/app/(dashboard)/inbox/[messageId]/utils" { authFetch }
    "src/lib/messages/detail-cache" --> "src/app/(dashboard)/inbox/[messageId]/utils" {
        fetchCachedMessageDetail,
        getCachedMessageDetail,
    }
    src.lib.email.address --> "src/app/(dashboard)/inbox/[messageId]/utils" {
        getEmailAddress,
        getEmailAddressList,
        normalizeEmailAddress,
    }
    "src/lib/email/recipient-display" --> "src/app/(dashboard)/inbox/[messageId]/utils" {
        formatRecipientAddressList,
    }
    src.lib.contacts.utils --> "src/app/(dashboard)/inbox/[messageId]/utils" {
        getDisplayNameForAddress,
    }
    "src/lib/email/reply-content-utils" --> "src/app/(dashboard)/inbox/[messageId]/utils" {
        htmlToReadableText,
        splitRepliedEmailContent,
    }
    "src/components/compose/rich-text-utils" --> "src/app/(dashboard)/inbox/[messageId]/utils" {
        splitQuotedHtml,
    }
    src.lib.email.html --> "src/app/(dashboard)/inbox/[messageId]/utils" { resolveEmailCidUrls }
    "src/hooks/types.d" --> "src/app/(dashboard)/inbox/[messageId]/utils" { Message }
    "src/app/(dashboard)/inbox/[messageId]/types.d" --> "src/app/(dashboard)/inbox/[messageId]/utils" {
        MessageAttachment,
        MessageBodyDisplay,
        MessageDetailResponse,
    }
    src.lib.email.address ++> "src/lib/email/recipient-display" {
        getEmailAddress,
        parseEmailAddressParts,
        splitEmailAddressList,
    }
    src.components.icons --> "src/components/message-attachment-card-utils" {
        FileArchive,
        FileCode,
        FileSpreadsheet,
        FileText,
        FileType,
        FileVideoCamera,
        Image,
        Music,
        Presentation,
    }
    "src/app/(dashboard)/inbox/[messageId]/types.d" --> "src/components/message-attachment-card-utils" {
        MessageAttachment,
    }
    "src/components/message-attachment-card-types.d" --> "src/components/message-attachment-card-utils" {
        AttachmentVisual,
    }
    "src/components/message-attachment-viewer-utils" --> "src/components/message-attachment-card-utils" {
        getAttachmentPreviewKind,
    }
    src.components.icons --> "src/components/message-invite-card" { CalendarDays, Check, X }
    "src/components/language-provider" --> "src/components/message-invite-card" { useLanguage }
    src.components.ui.button --> "src/components/message-invite-card" { Button }
    src.components.ui.dialog --> "src/components/message-invite-card" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.skeleton --> "src/components/message-invite-card" { Skeleton }
    src.lib.auth.client --> "src/components/message-invite-card" { authFetch }
    "src/lib/calendar/invite-cache" --> "src/components/message-invite-card" {
        cacheAnsweredInvite,
        fetchInviteCard,
        getCachedInviteCard,
    }
    "src/lib/calendar/invite-types.d" --> "src/components/message-invite-card" {
        InviteResponse,
        InviteView,
    }
    src.lib.time.utils --> "src/components/message-invite-card" { formatUserDate }
    src.components.icons --> "src/components/previous-message" { ChevronRight }
    "src/components/language-provider" --> "src/components/previous-message" { useLanguage }
    "src/components/previous-message-types.d" --> "src/components/previous-message" {
        PreviousMessageProps,
    }
    src.lib.time.utils --> "src/components/messages/conversation-thread" { formatUserDate }
    src.components.icons --> "src/components/messages/conversation-thread" {
        ChevronsUpDown,
        Paperclip,
    }
    "src/components/contacts/contact-avatar" --> "src/components/messages/conversation-thread" {
        ContactAvatar,
    }
    "src/components/messages/quoted-email-toggle" --> "src/components/messages/conversation-thread" {
        QuotedEmailToggle,
    }
    "src/components/message-actions/utils" --> "src/components/messages/conversation-thread" {
        runSingleMessageAction,
    }
    "src/components/messages/email-html-renderer" --> "src/components/messages/conversation-thread" {
        EmailHtmlRenderer,
    }
    "src/components/messages/use-remote-content" --> "src/components/messages/conversation-thread" {
        useRemoteContent,
    }
    "src/app/(dashboard)/inbox/[messageId]/utils" --> "src/components/messages/conversation-thread" {
        getMessageBodyDisplay,
        resolveInlineAttachmentUrls,
    }
    "src/components/language-provider" --> "src/components/messages/conversation-thread" {
        useLanguage,
    }
    src.lib.utils --> "src/components/messages/conversation-thread" { cn }
    "src/components/messages/conversation-thread-types.d" --> "src/components/messages/conversation-thread" {
        ConversationMessageCardProps,
        ConversationThreadProps,
    }
    "src/components/messages/thread-message-actions" --> "src/components/messages/conversation-thread" {
        ThreadMessageActions,
    }
    "src/components/messages/message-details-panel" --> "src/components/messages/conversation-thread" {
        MessageDetailsPanel,
    }
    "src/components/messages/sender-check-notice" --> "src/components/messages/conversation-thread" {
        SenderCheckBadge,
        SenderCheckNotice,
    }
    "src/components/messages/message-open-status" --> "src/components/messages/conversation-thread" {
        MessageOpenStatus,
    }
    "src/components/follow-ups/message-follow-up-status" --> "src/components/messages/conversation-thread" {
        MessageFollowUpStatus,
    }
    "src/components/messages/conversation-thread-utils" --> "src/components/messages/conversation-thread" {
        getConversationRecipients,
        getConversationSender,
        getConversationSenderEmail,
        partitionThread,
    }
    "src/components/messages/message-list-visibility" --> "src/components/messages/conversation-thread" {
        useMessageListVisibility,
    }
    "src/components/agent/assistant-open-state" --> "src/components/messages/conversation-thread" {
        useAssistantOpen,
    }
    "src/components/language-provider" --> "src/components/messages/quoted-email-toggle" {
        useLanguage,
    }
    "src/components/messages/quoted-email-toggle-types.d" --> "src/components/messages/quoted-email-toggle" {
        QuotedEmailToggleProps,
    }
    "src/components/messages/email-html-renderer" --> "src/components/messages/quoted-email-toggle" {
        EmailHtmlRenderer,
    }
    "src/components/messages/use-remote-content-utils" --> "src/components/messages/use-remote-content" {
        REMOTE_CONTENT_CHANGE_EVENT,
        RemoteContentPolicy,
        allowRemoteContentFromSender,
        loadRemoteContentPolicy,
        shouldAutoLoadRemote,
    }
    src.lib.auth.client --> "src/components/messages/use-remote-content-utils" { authFetch }
    src.components.icons --> "src/components/messages/thread-message-actions" {
        Ban,
        FileCode2,
        Forward,
        Info,
        Mail,
        MailOpen,
        MoreVertical,
        Note,
        Reply,
        ReplyAll,
        Star,
    }
    "src/components/compose/compose-context" --> "src/components/messages/thread-message-actions" {
        useCompose,
    }
    "src/components/messages/message-source-dialog" --> "src/components/messages/thread-message-actions" {
        MessageSourceDialog,
    }
    "src/components/message-actions/action-menu" --> "src/components/messages/thread-message-actions" {
        MessageActionMenu,
        MessageActionMenuItem,
        MessageActionMenuSeparator,
    }
    "src/app/(dashboard)/inbox/[messageId]/utils" --> "src/components/messages/thread-message-actions" {
        getOwnAddressForMessage,
    }
    "src/components/language-provider" --> "src/components/messages/thread-message-actions" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/messages/thread-message-actions" { Button }
    src.components.ui.tooltip --> "src/components/messages/thread-message-actions" { Tooltip }
    "src/components/ui/confirm-dialog" --> "src/components/messages/thread-message-actions" {
        confirmDestructive,
    }
    src.lib.utils --> "src/components/messages/thread-message-actions" { cn }
    "src/components/message-actions/utils" --> "src/components/messages/thread-message-actions" {
        blockMessageContact,
        canBlockSenderDomain,
        createForwardDraft,
        createReplyDraft,
        getBlockErrorKey,
        getMoveMessageActions,
        getReplyRecipients,
        getReplyThreading,
        getSenderDomain,
        hasAdditionalRecipients,
        runSingleMessageAction,
    }
    "src/components/messages/message-list-row-actions-utils" --> "src/components/messages/thread-message-actions" {
        toggleMessageStar,
    }
    "src/components/messages/conversation-notes-context" --> "src/components/messages/thread-message-actions" {
        useConversationNotes,
    }
    "src/components/messages/thread-message-actions-types.d" --> "src/components/messages/thread-message-actions" {
        ThreadMessageActionsProps,
    }
    "src/components/message-actions/types.d" --> "src/components/messages/thread-message-actions" {
        ReplyMode,
    }
    src.components.icons --> "src/components/messages/message-details-panel" {
        AlertTriangle,
        CheckCircle2,
        ExternalLink,
        LoaderCircle,
        ShieldAlert,
        ShieldCheck,
        X,
    }
    "src/components/language-provider" --> "src/components/messages/message-details-panel" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/messages/message-details-panel" { Button }
    src.lib.email.address --> "src/components/messages/message-details-panel" {
        splitEmailAddressList,
    }
    "src/lib/email/recipient-display" --> "src/components/messages/message-details-panel" {
        formatRecipientAddressList,
    }
    "src/lib/email/authentication-types.d" --> "src/components/messages/message-details-panel" {
        MessageAuthenticationMethod,
    }
    src.lib.time.utils --> "src/components/messages/message-details-panel" { formatUserDate }
    src.lib.utils --> "src/components/messages/message-details-panel" { cn }
    "src/components/messages/message-source-dialog" --> "src/components/messages/message-details-panel" {
        MessageSourceDialog,
    }
    "src/components/messages/message-details-types.d" --> "src/components/messages/message-details-panel" {
        MessageDetailsPanelProps,
    }
    "src/components/messages/use-message-authentication" --> "src/components/messages/message-details-panel" {
        useMessageAuthentication,
    }
    "src/components/messages/message-details-utils" --> "src/components/messages/message-details-panel" {
        getOriginalSender,
        getReplyToEntries,
        hasDomainMismatchWarning,
        hasFailingAuthenticationCheck,
        hasPassingAuthenticationCheck,
        hasSenderNameAddressMismatch,
        isReplyToDifferent,
    }
    "src/lib/email/authentication-types.d" --> "src/components/messages/use-message-authentication" {
        MessageAuthenticationResponse,
    }
    "src/components/messages/message-details-utils" --> "src/components/messages/use-message-authentication" {
        fetchMessageAuthentication,
    }
    src.lib.auth.client --> "src/components/messages/message-details-utils" { authFetch }
    src.lib.email.address --> "src/components/messages/message-details-utils" {
        getEmailAddress,
        normalizeEmailAddress,
        parseEmailAddressParts,
        splitEmailAddressList,
    }
    "src/lib/email/domain-match" --> "src/components/messages/message-details-utils" {
        isSameOrSubdomain,
    }
    "src/lib/email/authentication-types.d" --> "src/components/messages/message-details-utils" {
        MessageAuthenticationResponse,
    }
    "src/components/messages/message-details-types.d" --> "src/components/messages/message-details-utils" {
        MessageDetailsMessage,
    }
    src.components.icons --> "src/components/messages/sender-check-notice" {
        ChevronDown,
        ShieldAlert,
    }
    "src/components/language-provider" --> "src/components/messages/sender-check-notice" {
        useLanguage,
    }
    src.lib.utils --> "src/components/messages/sender-check-notice" { cn }
    "src/lib/i18n/types.d" --> "src/components/messages/sender-check-notice" { TranslationKey }
    "src/components/messages/message-details-utils" --> "src/components/messages/sender-check-notice" {
        SenderWarningReason,
        getSenderWarning,
    }
    "src/components/messages/use-message-authentication" --> "src/components/messages/sender-check-notice" {
        useMessageAuthentication,
    }
    "src/components/messages/sender-check-types.d" --> "src/components/messages/sender-check-notice" {
        SenderCheckBadgeProps,
        SenderCheckNoticeProps,
    }
    src.components.icons --> "src/components/messages/message-open-status" { Eye, EyeOff }
    "src/components/language-provider" --> "src/components/messages/message-open-status" {
        useLanguage,
    }
    src.lib.time.utils --> "src/components/messages/message-open-status" { formatUserDate }
    "src/lib/tracking/types.d" --> "src/components/messages/message-open-status" {
        MessageTrackingSummary,
    }
    "src/components/messages/message-open-status-utils" --> "src/components/messages/message-open-status" {
        describeOpenEvent,
        fetchMessageTracking,
    }
    src.lib.auth.client --> "src/components/messages/message-open-status-utils" { authFetch }
    "src/lib/tracking/types.d" --> "src/components/messages/message-open-status-utils" {
        MessageOpenEvent,
        MessageTrackingSummary,
    }
    src.components.icons --> "src/components/follow-ups/message-follow-up-status" {
        BellRing,
        Check,
    }
    "src/components/language-provider" --> "src/components/follow-ups/message-follow-up-status" {
        useLanguage,
    }
    "src/lib/follow-ups/types.d" --> "src/components/follow-ups/message-follow-up-status" {
        MessageFollowUp,
    }
    src.lib.time.utils --> "src/components/follow-ups/message-follow-up-status" { formatUserDate }
    "src/components/follow-ups/follow-up-menu" --> "src/components/follow-ups/message-follow-up-status" {
        FollowUpMenu,
    }
    "src/components/follow-ups/follow-up-client-utils" --> "src/components/follow-ups/message-follow-up-status" {
        FOLLOW_UPS_CHANGED_EVENT,
        clearMessageFollowUp,
        fetchMessageFollowUp,
        setMessageFollowUp,
    }
    src.lib.email.address --> "src/components/messages/conversation-thread-utils" {
        getEmailAddress,
        getEmailDisplayName,
        splitEmailAddressList,
    }
    "src/lib/email/recipient-display" --> "src/components/messages/conversation-thread-utils" {
        RecipientAddressStyle,
        formatRecipientAddress,
    }
    "src/hooks/types.d" --> "src/components/messages/conversation-thread-utils" { ThreadMessage }
    "src/components/ui/confirm-dialog" --> "src/components/messages/conversation-notes" {
        confirmDestructive,
    }
    src.components.icons --> "src/components/messages/conversation-notes" {
        ChevronDown,
        Mail,
        Note,
        PenLine,
        Trash2,
        X,
    }
    "src/components/language-provider" --> "src/components/messages/conversation-notes" {
        useLanguage,
    }
    "src/components/progressive-avatar-image" --> "src/components/messages/conversation-notes" {
        ProgressiveAvatarImage,
    }
    "src/components/compose/rich-text-editor" --> "src/components/messages/conversation-notes" {
        RichTextEditor,
    }
    "src/components/compose/rich-text-utils" --> "src/components/messages/conversation-notes" {
        htmlToPlainText,
    }
    src.components.ui.button --> "src/components/messages/conversation-notes" { Button }
    src.components.ui.tooltip --> "src/components/messages/conversation-notes" { Tooltip }
    "src/lib/avatar-colors" --> "src/components/messages/conversation-notes" { getAvatarColorStyle }
    src.lib.time.utils --> "src/components/messages/conversation-notes" { formatUserDate }
    src.lib.utils --> "src/components/messages/conversation-notes" { cn }
    "src/lib/notes/types.d" --> "src/components/messages/conversation-notes" { ConversationNote }
    "src/components/messages/email-html-renderer" --> "src/components/messages/conversation-notes" {
        EmailHtmlRenderer,
    }
    "src/components/messages/conversation-notes-context" --> "src/components/messages/conversation-notes" {
        useConversationNotes,
    }
    "src/components/messages/conversation-notes-types.d" --> "src/components/messages/conversation-notes" {
        ConversationNotesProps,
    }
    src.components.icons --> "src/components/messages/message-reading-header-button" {
        ArrowLeft,
        Columns2,
    }
    "src/components/language-provider" --> "src/components/messages/message-reading-header-button" {
        useLanguage,
    }
    src.components.ui.tooltip --> "src/components/messages/message-reading-header-button" {
        Tooltip,
    }
    "src/components/messages/message-list-visibility" --> "src/components/messages/message-reading-header-button" {
        useMessageListVisibility,
    }
    "src/components/messages/message-reading-header-button-types.d" --> "src/components/messages/message-reading-header-button" {
        MessageReadingHeaderButtonProps,
    }
    "src/components/ui/confirm-dialog" --> "src/components/messages/scheduled-send-banner" {
        alertDialog,
    }
    src.components.icons --> "src/components/messages/scheduled-send-banner" { CalendarClock }
    "src/components/language-provider" --> "src/components/messages/scheduled-send-banner" {
        useLanguage,
    }
    "src/components/compose/compose-context" --> "src/components/messages/scheduled-send-banner" {
        useCompose,
    }
    src.lib.auth.client --> "src/components/messages/scheduled-send-banner" { authFetch }
    "src/lib/messages/detail-cache" --> "src/components/messages/scheduled-send-banner" {
        clearMessageDetailCache,
    }
    "src/components/messages/scheduled-send-reschedule" --> "src/components/messages/scheduled-send-banner" {
        ScheduledSendReschedule,
    }
    "src/components/messages/scheduled-send-utils" --> "src/components/messages/scheduled-send-banner" {
        formatScheduledSendTime,
    }
    "src/components/language-provider" --> "src/components/messages/scheduled-send-reschedule" {
        useLanguage,
    }
    "src/components/sidebar-mobile-utils" --> "src/components/messages/scheduled-send-reschedule" {
        useIsMobile,
    }
    "src/components/compose/schedule-send-sheet" --> "src/components/messages/scheduled-send-reschedule" {
        ScheduleSendSheet,
    }
    "src/components/compose/schedule-send-utils" --> "src/components/messages/scheduled-send-reschedule" {
        formatDateTimeLocal,
        formatScheduledSend,
        getScheduleSendOptions,
        isPastSchedule,
        parseDateTimeLocal,
    }
    src.lib.time.utils --> "src/components/messages/scheduled-send-reschedule" { getUserTimeZone }
    src.components.icons --> "src/components/messages/unsubscribe-button" { BellOff, MailCheck }
    "src/components/compose/compose-context" --> "src/components/messages/unsubscribe-button" {
        useCompose,
    }
    "src/components/language-provider" --> "src/components/messages/unsubscribe-button" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/messages/unsubscribe-button" { Button }
    src.components.ui.dialog --> "src/components/messages/unsubscribe-button" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.tooltip --> "src/components/messages/unsubscribe-button" { Tooltip }
    "src/components/message-actions/utils" --> "src/components/messages/unsubscribe-button" {
        openUnsubscribeUrl,
    }
    "src/components/messages/unsubscribe-button-utils" --> "src/components/messages/unsubscribe-button" {
        isMessageUnsubscribed,
        markMessageUnsubscribed,
        requestUnsubscribe,
    }
    "src/hooks/types.d" --> "src/components/messages/use-message-thread" { ThreadMessage }
    "src/lib/messages/field-store" --> "src/components/messages/use-message-thread" {
        applyPendingToMessages,
        subscribePendingOverlay,
    }
    "src/components/messages/message-thread-cache" --> "src/components/messages/use-message-thread" {
        fetchMessageThread,
        getCachedMessageThread,
        isMessageThreadInvalidated,
        markMessageThreadReadInCaches,
    }
    "src/components/messages/conversation-thread-types.d" --> "src/components/messages/use-message-thread" {
        UseMessageThreadResult,
    }
    "src/components/contacts/contact-details" --> "src/components/messages/recipient-list" {
        ContactDetailsTrigger,
    }
    src.lib.email.address --> "src/components/messages/recipient-list" { getEmailAddress }
    "src/lib/email/recipient-display" --> "src/components/messages/recipient-list" {
        RecipientAddressStyle,
        formatRecipientAddress,
        recipientContactName,
    }
    "src/components/messages/use-show-full-recipient-addresses-utils" --> "src/components/messages/use-show-full-recipient-addresses" {
        loadShowFullRecipientAddresses,
        updateShowFullRecipientAddresses,
    }
    src.lib.auth.client --> "src/components/messages/use-show-full-recipient-addresses-utils" {
        authFetch,
    }
    "src/app/(dashboard)/inbox/[messageId]/cloud-attachment-types.d" --> "src/app/(dashboard)/inbox/[messageId]/cloud-attachment-utils" {
        CloudAttachment,
        CloudAttachmentExtraction,
    }
    src.lib.auth.client --> "src/components/messages/use-send-view-status" { authFetch }
    "src/lib/messages/detail-cache" --> "src/components/messages/use-send-view-status" {
        clearMessageDetailCache,
    }
    "src/components/messages/send-view-utils" --> "src/components/messages/use-send-view-status" {
        resolveSendViewRoute,
    }
    src.components.icons --> "src/components/messages/mailing-list-banner" { Mail, X }
    "src/components/language-provider" --> "src/components/messages/mailing-list-banner" {
        useLanguage,
    }
    "src/components/messages/unsubscribe-button" --> "src/components/messages/mailing-list-banner" {
        MessageUnsubscribeButton,
    }
    "src/components/messages/message-folder-configs" --> "src/app/(dashboard)/archived/layout" {
        archivedFolderConfig,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/archived/layout" {
        MessageSplitLayout,
    }
    src.components.icons --> "src/components/messages/message-folder-configs" {
        Archive,
        CalendarClock,
        Clock,
        MailOpen,
        Send,
        ShieldAlert,
        Star,
        Tag,
        Trash2,
    }
    "src/components/messages/types.d" --> "src/components/messages/message-folder-configs" {
        MessageFolderConfig,
    }
    "src/components/language-provider" --> "src/components/messages/message-split-layout" {
        useLanguage,
    }
    "src/components/sidebar-state" --> "src/components/messages/message-split-layout" { useSidebar }
    "src/components/agent/assistant-open-state" --> "src/components/messages/message-split-layout" {
        useAssistantOpen,
    }
    "src/components/mail-search/mail-search-context" --> "src/components/messages/message-split-layout" {
        useMailSearch,
    }
    "src/components/mailbox-provider" --> "src/components/messages/message-split-layout" {
        useSelectedMailbox,
    }
    "src/components/sidebar-mobile-utils" --> "src/components/messages/message-split-layout" {
        useIsDesktop,
    }
    "src/components/column-width-preferences" --> "src/components/messages/message-split-layout" {
        readColumnWidth,
        readInitialColumnWidth,
        saveColumnWidth,
    }
    "src/components/ui/resize-handle" --> "src/components/messages/message-split-layout" {
        ResizeHandle,
    }
    "src/components/messages/bulk-message-action-bar" --> "src/components/messages/message-split-layout" {
        BulkMessageActionBar,
    }
    "src/components/messages/message-folder-page" --> "src/components/messages/message-split-layout" {
        MessageFolderPage,
    }
    "src/components/messages/message-detail-navigation" --> "src/components/messages/message-split-layout" {
        MessageDetailNavigationProvider,
    }
    "src/components/messages/message-list-state" --> "src/components/messages/message-split-layout" {
        MessageListStateContext,
    }
    "src/components/messages/message-list-visibility" --> "src/components/messages/message-split-layout" {
        MessageListVisibilityContext,
    }
    "src/components/messages/message-list-visibility-utils" --> "src/components/messages/message-split-layout" {
        readInitialMessageListVisible,
        saveMessageListVisible,
    }
    "src/components/messages/use-conversation-view" --> "src/components/messages/message-split-layout" {
        useConversationView,
    }
    "src/components/messages/use-two-column-reading" --> "src/components/messages/message-split-layout" {
        useTwoColumnReading,
    }
    "src/components/messages/types.d" --> "src/components/messages/message-split-layout" {
        MessageListStateControl,
        MessageSplitLayoutProps,
        SelectedMessage,
    }
    "src/app/api/messages/bulk/types.d" --> "src/components/messages/bulk-message-action-bar" {
        BulkMessageAction,
    }
    "src/components/language-provider" --> "src/components/messages/bulk-message-action-bar" {
        useLanguage,
    }
    "src/components/messages/bulk-message-toolbar" --> "src/components/messages/bulk-message-action-bar" {
        BulkMessageToolbar,
    }
    "src/components/messages/types.d" --> "src/components/messages/bulk-message-action-bar" {
        BulkMessageActionBarProps,
    }
    "src/components/ui/confirm-dialog" --> "src/components/messages/bulk-message-action-bar" {
        confirmDestructive,
    }
    "src/lib/messages/permanent-delete-utils" --> "src/components/messages/bulk-message-action-bar" {
        PartialDeleteError,
        getPermanentDeleteConfirmText,
    }
    src.components.messages.utils --> "src/components/messages/bulk-message-action-bar" {
        runBulkMessageAction,
    }
    src.components.icons --> "src/components/messages/bulk-message-toolbar" {
        Archive,
        ArchiveRestore,
        ChevronDown,
        Folder,
        FolderInput,
        Inbox,
        Mail,
        MailOpen,
        MoreVertical,
        ShieldAlert,
        ShieldCheck,
        Trash2,
        Undo2,
        X,
    }
    "src/components/language-provider" --> "src/components/messages/bulk-message-toolbar" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/messages/bulk-message-toolbar" { Button }
    "src/components/mailbox-provider" --> "src/components/messages/bulk-message-toolbar" {
        useSelectedMailbox,
    }
    "src/components/messages/use-mailbox-folders" --> "src/components/messages/bulk-message-toolbar" {
        useMailboxFolders,
    }
    src.components.ui.tooltip --> "src/components/messages/bulk-message-toolbar" { Tooltip }
    "src/lib/messages/permanent-delete-utils" --> "src/components/messages/bulk-message-toolbar" {
        supportsPermanentDelete,
    }
    "src/app/api/messages/bulk/types.d" --> "src/components/messages/bulk-message-toolbar" {
        BulkMessageAction,
    }
    "src/components/messages/types.d" --> "src/components/messages/bulk-message-toolbar" {
        BulkMessageToolbarProps,
    }
    src.lib.folders.client --> "src/components/messages/use-mailbox-folders" { getMailboxFolders }
    src.lib.auth.client --> "src/components/messages/use-mailbox-folders" { getClientSessionToken }
    "src/components/dashboard-nav-types.d" --> "src/components/messages/use-mailbox-folders" {
        CustomFolder,
    }
    src.lib.auth.client --> src.lib.folders.client {
        AUTH_SESSION_CHANGED_EVENT,
        authFetch,
        getClientSessionToken,
    }
    "src/hooks/types.d" --> src.components.messages.utils { Message }
    src.lib.auth.client --> src.components.messages.utils { authFetch }
    "src/lib/messages/change-events" --> src.components.messages.utils { dispatchMessagesChanged }
    src.lib.messages.actions.client --> src.components.messages.utils { performMessageAction }
    src.lib.messages.actions.definitions --> src.components.messages.utils {
        isReversibleMessageAction,
    }
    src.lib.email.address --> src.components.messages.utils {
        getEmailDisplayName,
        splitEmailAddressList,
    }
    src.lib.time.utils --> src.components.messages.utils {
        formatUserDate,
        getUserTimeZone,
        zonedDateFields,
    }
    "src/components/mailbox-provider" --> src.components.messages.utils { MailboxOption }
    "src/components/messages/types.d" --> src.components.messages.utils {
        EmailPageTitleInput,
        MessageFolderConfig,
        PageRange,
    }
    src.lib.i18n.utils --> src.components.messages.utils { Translator, defaultTranslator }
    "src/app/api/messages/bulk/types.d" --> src.components.messages.utils { PermanentDeleteFolder }
    "src/lib/messages/permanent-delete-utils" --> src.components.messages.utils {
        throwIfDeleteSkipped,
    }
    "src/app/api/messages/empty/types.d" --> src.components.messages.utils { EmptyFolderResponse }
    "src/components/ui/confirm-dialog" --> "src/components/messages/message-folder-page" {
        alertDialog,
        confirmDestructive,
    }
    src.components.icons --> "src/components/messages/message-folder-page" {
        Archive,
        ChevronLeft,
        ChevronRight,
        ListFilter,
        Mail,
        MailOpen,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/messages/message-folder-page" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/messages/message-folder-page" { Button }
    src.components.ui.checkbox --> "src/components/messages/message-folder-page" { Checkbox }
    src.components.ui.tooltip --> "src/components/messages/message-folder-page" { Tooltip }
    "src/components/mail-search/mail-search-context" --> "src/components/messages/message-folder-page" {
        useMailSearch,
    }
    "src/components/mailbox-provider" --> "src/components/messages/message-folder-page" {
        useSelectedMailbox,
    }
    "src/components/page-loading" --> "src/components/messages/message-folder-page" {
        usePageLoading,
    }
    "src/components/messages/scheduled-send-utils" --> "src/components/messages/message-folder-page" {
        formatScheduledSendTime,
    }
    "src/components/sidebar-mobile-utils" --> "src/components/messages/message-folder-page" {
        useHasHover,
        useIsDesktop,
        useIsMobile,
    }
    "src/hooks/use-message-counts" --> "src/components/messages/message-folder-page" {
        useMessageCounts,
    }
    "src/hooks/use-messages" --> "src/components/messages/message-folder-page" { useMessages }
    "src/app/api/messages/bulk/types.d" --> "src/components/messages/message-folder-page" {
        BulkMessageAction,
    }
    "src/hooks/types.d" --> "src/components/messages/message-folder-page" { Message }
    "src/lib/messages/drag-utils" --> "src/components/messages/message-folder-page" {
        setMessageDragData,
    }
    "src/components/messages/bulk-message-toolbar" --> "src/components/messages/message-folder-page" {
        BulkMessageToolbar,
    }
    "src/components/messages/message-list-refresh-button" --> "src/components/messages/message-folder-page" {
        MessageListRefreshButton,
    }
    "src/components/messages/message-list-state" --> "src/components/messages/message-folder-page" {
        useMessageListState,
    }
    "src/components/messages/page-offset" --> "src/components/messages/message-folder-page" {
        getEmptyPageOffset,
    }
    "src/components/messages/swipeable-row" --> "src/components/messages/message-folder-page" {
        SwipeableRow,
    }
    "src/components/messages/message-list-row-actions" --> "src/components/messages/message-folder-page" {
        MessageListRowActions,
    }
    "src/components/messages/message-list-row-actions-utils" --> "src/components/messages/message-folder-page" {
        dispatchMessageCountsDelta,
        toggleMessageStar,
    }
    "src/components/messages/message-navigation" --> "src/components/messages/message-folder-page" {
        useMessageNavigation,
    }
    "src/components/messages/message-detail-navigation-utils" --> "src/components/messages/message-folder-page" {
        rememberOpenedUnreadMessage,
    }
    "src/components/messages/use-conversation-view" --> "src/components/messages/message-folder-page" {
        useConversationView,
    }
    "src/components/messages/message-open-status" --> "src/components/messages/message-folder-page" {
        OpenedIndicator,
    }
    "src/components/messages/message-notes-popover" --> "src/components/messages/message-folder-page" {
        MessageNotesPopover,
        NoteBadge,
    }
    "src/components/messages/types.d" --> "src/components/messages/message-folder-page" {
        MessageFolderConfig,
        MessageFolderPageProps,
        MessageListRowProps,
        RowMessageAction,
    }
    src.components.messages.utils --> "src/components/messages/message-folder-page" {
        emptyMessageFolder,
        formatEmailPageTitle,
        formatMessageListTimestamp,
        getMailboxAddress,
        getMessageParty,
        getMessagePartyClassName,
        getMessagePreview,
        getPageRange,
        getUnreadFlipCount,
        isMessageListRowUnread,
        runBulkMessageAction,
    }
    "src/lib/messages/permanent-delete-utils" --> "src/components/messages/message-folder-page" {
        PartialDeleteError,
        getEmptyFolderConfirmText,
        getEmptyFolderLabel,
        getPermanentDeleteConfirmText,
        getPermanentDeleteFolderLabel,
        supportsPermanentDelete,
    }
    "src/components/follow-ups/due-follow-ups" --> "src/components/messages/message-folder-page" {
        DueFollowUps,
    }
    src.lib.time.utils --> "src/components/messages/message-folder-page" {
        getUserTimeZone,
        zonedDateFields,
    }
    "src/lib/promotions/move-client" --> "src/components/messages/message-folder-page" {
        moveMessagesToCategory,
    }
    "src/lib/promotions/move-utils" --> "src/components/messages/message-folder-page" {
        canMoveCategory,
        moveTargetFor,
        showsPromotionChip,
    }
    "src/lib/promotions/ui-utils" --> "src/components/messages/message-folder-page" {
        UnreadDeltas,
        hasActivePromotions,
        mergeUnreadDeltas,
        negateUnreadDeltas,
        unreadDeltas,
    }
    "src/hooks/types.d" --> "src/hooks/use-messages" {
        Message,
        MessageFilterOptions,
        MessageFolder,
    }
    src.lib.messages.actions.definitions --> "src/hooks/use-messages" { getMessageActionPatch }
    "src/lib/messages/change-events" --> "src/hooks/use-messages" { MessagesChangedDetail }
    "src/lib/messages/field-store" --> "src/hooks/use-messages" {
        ThreadUnreadTarget,
        applyPendingToMessages,
        getKnownThreadUnread,
        subscribePendingOverlay,
    }
    "src/hooks/message-refresh" --> "src/hooks/use-messages" { registerMessageRefresh }
    "src/lib/messages/membership-store" --> "src/hooks/use-messages" {
        RestoredRow,
        getRestoredRowsForList,
        rememberRemovedRow,
        updateRemovedRows,
    }
    "src/lib/messages/list-membership" --> "src/hooks/use-messages" {
        MessageMembershipFields,
        getListMembershipKey,
        messageMatchesFolder,
    }
    src.hooks.utils --> "src/hooks/use-messages" {
        clearMessageCountsCache,
        clearMessageListCache,
        fetchMessageList,
        getMessageQueryParams,
        peekMessageList,
    }
    src.components.icons --> "src/components/messages/message-list-refresh-button" { RefreshCw }
    "src/components/language-provider" --> "src/components/messages/message-list-refresh-button" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/messages/message-list-refresh-button" { Button }
    src.components.ui.tooltip --> "src/components/messages/message-list-refresh-button" { Tooltip }
    "src/hooks/message-refresh" --> "src/components/messages/message-list-refresh-button" {
        refreshMessageViews,
    }
    "src/components/messages/types.d" --> "src/components/messages/message-list-state" {
        MessageListStateControl,
    }
    src.components.icons --> "src/components/messages/swipeable-row" { LucideIcon }
    src.components.icons --> "src/components/messages/message-list-row-actions" {
        Archive,
        ArchiveRestore,
        Clock,
        Inbox,
        Mail,
        MailOpen,
        MoreVertical,
        ShieldCheck,
        Tag,
        Trash2,
        Undo2,
    }
    "src/components/message-actions/action-menu" --> "src/components/messages/message-list-row-actions" {
        MessageActionMenu,
        MessageActionMenuItem,
        MessageActionMenuSeparator,
    }
    "src/components/language-provider" --> "src/components/messages/message-list-row-actions" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/messages/message-list-row-actions" { Button }
    "src/components/ui/confirm-dialog" --> "src/components/messages/message-list-row-actions" {
        confirmDestructive,
    }
    src.components.ui.dialog --> "src/components/messages/message-list-row-actions" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/messages/message-list-row-actions" { Input }
    src.components.ui.tooltip --> "src/components/messages/message-list-row-actions" { Tooltip }
    "src/components/messages/types.d" --> "src/components/messages/message-list-row-actions" {
        MessageListRowActionsProps,
    }
    "src/components/messages/unsubscribe-button" --> "src/components/messages/message-list-row-actions" {
        MessageUnsubscribeButton,
    }
    "src/components/messages/message-list-row-actions-utils" --> "src/components/messages/message-list-row-actions" {
        SnoozePreset,
        getSnoozePresets,
        isMessageSnoozed,
        snoozeMessage,
        unsnoozeMessage,
    }
    src.lib.time.utils --> "src/components/messages/message-list-row-actions" { getUserTimeZone }
    "src/lib/messages/detail-cache" --> "src/components/messages/message-navigation" {
        fetchCachedMessageDetail,
        getCachedMessageDetail,
        primeMessageDetail,
    }
    "src/lib/calendar/invite-cache" --> "src/components/messages/message-navigation" {
        fetchInviteCard,
        getCachedInviteCard,
    }
    "src/lib/calendar/invite-attachment" --> "src/components/messages/message-navigation" {
        findInviteAttachment,
    }
    src.lib.navigation.prefetch --> "src/components/messages/message-navigation" {
        FULL_ROUTE_PREFETCH,
    }
    "src/hooks/types.d" --> "src/components/messages/message-navigation" { Message }
    "src/lib/messages/detail-cache-types.d" --> "src/components/messages/message-navigation" {
        CachedMessageDetail,
    }
    "src/components/messages/message-navigation-types.d" --> "src/components/messages/message-navigation" {
        MessageNavigationState,
    }
    src.components.icons --> "src/components/messages/message-notes-popover" { Note }
    "src/components/language-provider" --> "src/components/messages/message-notes-popover" {
        useLanguage,
    }
    "src/components/messages/conversation-notes-context" --> "src/components/messages/message-notes-popover" {
        ConversationNotesProvider,
        useConversationNotes,
    }
    "src/components/messages/conversation-notes" --> "src/components/messages/message-notes-popover" {
        NotesBody,
    }
    src.components.icons --> "src/components/follow-ups/due-follow-ups" { BellRing, Check }
    "src/components/language-provider" --> "src/components/follow-ups/due-follow-ups" {
        useLanguage,
    }
    src.components.ui.tooltip --> "src/components/follow-ups/due-follow-ups" { Tooltip }
    "src/lib/follow-ups/types.d" --> "src/components/follow-ups/due-follow-ups" { DueFollowUp }
    src.lib.time.utils --> "src/components/follow-ups/due-follow-ups" { formatUserDate }
    "src/components/follow-ups/follow-up-menu" --> "src/components/follow-ups/due-follow-ups" {
        FollowUpMenu,
    }
    "src/components/follow-ups/follow-up-client-utils" --> "src/components/follow-ups/due-follow-ups" {
        FOLLOW_UPS_CHANGED_EVENT,
        fetchDueFollowUps,
        updateDueFollowUp,
    }
    "src/lib/i18n/types.d" --> "src/lib/promotions/ui-utils" { TranslationKey }
    "src/components/language-provider" --> "src/app/(dashboard)/compose/page" { useLanguage }
    "src/components/compose/compose-form" --> "src/app/(dashboard)/compose/page" { ComposeForm }
    "src/components/contacts/contacts-page" --> "src/app/(dashboard)/contacts/page" { ContactsPage }
    src.components.icons --> "src/components/contacts/contacts-page" { Plus, Search, UsersRound }
    "src/components/language-provider" --> "src/components/contacts/contacts-page" { useLanguage }
    "src/components/compose/compose-context" --> "src/components/contacts/contacts-page" {
        useCompose,
    }
    "src/components/mailbox-provider" --> "src/components/contacts/contacts-page" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/components/contacts/contacts-page" { Button }
    src.components.ui.input --> "src/components/contacts/contacts-page" { Input }
    src.components.ui.list --> "src/components/contacts/contacts-page" { List }
    "src/components/page-skeletons" --> "src/components/contacts/contacts-page" {
        SectionRowSkeleton,
    }
    "src/components/page-header-utils" --> "src/components/contacts/contacts-page" {
        mobilePrimaryActionClass,
    }
    src.lib.email.address --> "src/components/contacts/contacts-page" { formatEmailAddress }
    "src/components/contacts/contact-delete-dialog" --> "src/components/contacts/contacts-page" {
        ContactDeleteDialog,
    }
    "src/components/contacts/contact-edit-dialog" --> "src/components/contacts/contacts-page" {
        ContactEditDialog,
    }
    "src/components/contacts/contact-row" --> "src/components/contacts/contacts-page" { ContactRow }
    "src/components/contacts/contacts-page-utils" --> "src/components/contacts/contacts-page" {
        CONTACT_COLUMNS,
        fetchContacts,
    }
    "src/components/contacts/contacts-page-types.d" --> "src/components/contacts/contacts-page" {
        ContactListItem,
    }
    "src/components/language-provider" --> "src/components/contacts/contact-delete-dialog" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/contacts/contact-delete-dialog" { Button }
    src.components.ui.dialog --> "src/components/contacts/contact-delete-dialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    "src/components/contacts/contacts-page-types.d" --> "src/components/contacts/contact-delete-dialog" {
        ContactDeleteDialogProps,
        ContactListItem,
    }
    "src/components/contacts/contacts-page-utils" --> "src/components/contacts/contact-delete-dialog" {
        deleteContact,
    }
    src.lib.auth.client --> "src/components/contacts/contacts-page-utils" { authFetch }
    "src/components/contacts/contacts-page-types.d" --> "src/components/contacts/contacts-page-utils" {
        ContactListItem,
        ContactMutationResponse,
        ContactsListResponse,
    }
    "src/components/language-provider" --> "src/components/contacts/contact-edit-dialog" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/contacts/contact-edit-dialog" { Button }
    src.components.ui.dialog --> "src/components/contacts/contact-edit-dialog" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/contacts/contact-edit-dialog" { Input }
    src.components.ui.label --> "src/components/contacts/contact-edit-dialog" { Label }
    src.lib.utils --> "src/components/contacts/contact-edit-dialog" { parseAddress }
    "src/components/contacts/contact-avatar-form" --> "src/components/contacts/contact-edit-dialog" {
        ContactAvatarForm,
    }
    "src/components/contacts/contact-details-types.d" --> "src/components/contacts/contact-edit-dialog" {
        ContactDetailsRecord,
    }
    "src/components/contacts/contact-details-utils" --> "src/components/contacts/contact-edit-dialog" {
        fetchContactDetails,
    }
    "src/components/contacts/contact-imported-details" --> "src/components/contacts/contact-edit-dialog" {
        ContactImportedDetails,
    }
    "src/components/contacts/contacts-page-types.d" --> "src/components/contacts/contact-edit-dialog" {
        ContactEditDialogProps,
        ContactListItem,
    }
    "src/components/contacts/contacts-page-utils" --> "src/components/contacts/contact-edit-dialog" {
        createContact,
        renameContact,
    }
    src.components.icons --> "src/components/contacts/contact-row" {
        Ban,
        Edit04,
        MailSend01,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/contacts/contact-row" { useLanguage }
    src.components.ui.button --> "src/components/contacts/contact-row" { Button }
    src.components.ui.list --> "src/components/contacts/contact-row" { ListRow }
    src.components.ui.tooltip --> "src/components/contacts/contact-row" { Tooltip }
    src.lib.time.utils --> "src/components/contacts/contact-row" { formatUserDate }
    "src/components/contacts/contact-avatar" --> "src/components/contacts/contact-row" {
        ContactAvatar,
    }
    "src/components/contacts/contacts-page-types.d" --> "src/components/contacts/contact-row" {
        ContactRowProps,
    }
    "src/components/contacts/contacts-page-utils" --> "src/components/contacts/contact-row" {
        CONTACT_COLUMNS,
    }
    "src/components/compose/compose-context" --> "src/app/(dashboard)/drafts/[messageId]/open-draft-on-route" {
        useCompose,
    }
    "src/app/(dashboard)/drafts/[messageId]/types.d" --> "src/app/(dashboard)/drafts/[messageId]/open-draft-on-route" {
        OpenDraftOnRouteProps,
    }
    "src/app/(dashboard)/drafts/page" --> "src/app/(dashboard)/drafts/[messageId]/page" { default }
    "src/app/(dashboard)/drafts/[messageId]/open-draft-on-route" --> "src/app/(dashboard)/drafts/[messageId]/page" {
        OpenDraftOnRoute,
    }
    "src/app/(dashboard)/drafts/[messageId]/types.d" --> "src/app/(dashboard)/drafts/[messageId]/page" {
        DraftRoutePageProps,
    }
    src.components.icons --> "src/app/(dashboard)/drafts/page" { FileText }
    "src/components/messages/message-folder-page" --> "src/app/(dashboard)/drafts/page" {
        MessageFolderPage,
    }
    "src/components/messages/types.d" --> "src/app/(dashboard)/drafts/page" { MessageFolderConfig }
    "src/app/(dashboard)/inbox/[messageId]/page" --> "src/app/(dashboard)/folders/[folderId]/[messageId]/page" {
        default,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/folders/[folderId]/layout" {
        MessageSplitLayout,
    }
    "src/components/messages/use-custom-folder-config" --> "src/app/(dashboard)/folders/[folderId]/layout" {
        useCustomFolderConfig,
    }
    src.components.icons --> "src/components/messages/use-custom-folder-config" { Folder }
    "src/components/mailbox-provider" --> "src/components/messages/use-custom-folder-config" {
        useSelectedMailbox,
    }
    src.lib.folders.client --> "src/components/messages/use-custom-folder-config" {
        getMailboxFolders,
    }
    "src/components/messages/custom-folder-config-types.d" --> "src/components/messages/use-custom-folder-config" {
        CustomFolderSummary,
    }
    "src/components/messages/types.d" --> "src/components/messages/use-custom-folder-config" {
        MessageFolderConfig,
    }
    "src/components/messages/message-folder-configs" --> "src/app/(dashboard)/inbox/layout" {
        inboxFolderConfig,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/inbox/layout" {
        MessageSplitLayout,
    }
    "src/components/skip-to-content" --> "src/app/(dashboard)/layout" { SkipToContent }
    src.components.icons --> "src/app/(dashboard)/layout" { Sparkles }
    "src/components/language-provider" --> "src/app/(dashboard)/layout" { useLanguage }
    "src/components/auth/auth-guard" --> "src/app/(dashboard)/layout" { AuthGuard }
    "src/components/compose/compose-context" --> "src/app/(dashboard)/layout" { ComposeProvider }
    "src/components/compose/floating-composer" --> "src/app/(dashboard)/layout" { FloatingComposer }
    "src/components/mail-search/mail-search-input" --> "src/app/(dashboard)/layout" {
        MailSearchInput,
    }
    "src/components/mail-search/mail-search-context" --> "src/app/(dashboard)/layout" {
        MailSearchProvider,
    }
    "src/components/mailbox-provider" --> "src/app/(dashboard)/layout" { MailboxProvider }
    "src/components/mailbox-selector" --> "src/app/(dashboard)/layout" { MailboxSelector }
    "src/components/agent/agent-panel" --> "src/app/(dashboard)/layout" { AgentPanel }
    "src/components/agent/assistant-open-state" --> "src/app/(dashboard)/layout" {
        AssistantOpenContext,
    }
    src.components.ui.button --> "src/app/(dashboard)/layout" { Button }
    "src/components/dns-skipped-banner" --> "src/app/(dashboard)/layout" { DnsSkippedBanner }
    "src/components/license-indicator" --> "src/app/(dashboard)/layout" { LicenseIndicator }
    "src/components/dashboard-nav" --> "src/app/(dashboard)/layout" { DashboardNav }
    "src/components/sidebar-state" --> "src/app/(dashboard)/layout" { SidebarProvider }
    "src/components/sidebar-aside" --> "src/app/(dashboard)/layout" {
        MobileMenuButton,
        SidebarAside,
    }
    "src/components/sidebar-resize-boundary" --> "src/app/(dashboard)/layout" {
        SidebarResizeBoundary,
    }
    src.components.shortcuts.index --> "src/app/(dashboard)/layout" { ShortcutsProvider }
    "src/app/(dashboard)/dashboard-state" --> "src/app/(dashboard)/layout" { useDashboardState }
    "src/app/(dashboard)/use-assistant-availability" --> "src/app/(dashboard)/layout" {
        useAssistantAvailability,
    }
    "src/components/route-title" --> "src/app/(dashboard)/layout" { RouteTitle }
    "src/hooks/use-app-badge" --> "src/app/(dashboard)/layout" { useAppBadge }
    "src/components/messages/undo-toasts" --> "src/app/(dashboard)/layout" { UndoToasts }
    "src/components/messages/promotion-toast" --> "src/app/(dashboard)/layout" { PromotionToast }
    src.components.icons --> "src/components/mail-search/mail-search-input" { X }
    "src/components/language-provider" --> "src/components/mail-search/mail-search-input" {
        useLanguage,
    }
    "src/components/header-search" --> "src/components/mail-search/mail-search-input" {
        HeaderSearch,
    }
    "src/components/mail-search/mail-search-context" --> "src/components/mail-search/mail-search-input" {
        useMailSearch,
    }
    src.components.shortcuts.index --> "src/components/mail-search/mail-search-input" {
        useShortcuts,
    }
    src.components.icons --> "src/components/header-search" { Search }
    src.components.ui.input --> "src/components/header-search" { Input }
    "src/components/header-search-types.d" --> "src/components/header-search" { HeaderSearchProps }
    src.components.icons --> "src/components/dns-skipped-banner" { AlertTriangle }
    src.lib.auth.client --> "src/components/dns-skipped-banner" { authFetch }
    "src/hooks/use-current-user" --> "src/components/dns-skipped-banner" { useCurrentUser }
    "src/components/language-provider" --> "src/components/dns-skipped-banner" { useLanguage }
    src.components.ui.button --> "src/components/dns-skipped-banner" { Button }
    "src/components/language-provider" --> "src/components/dashboard-nav" { useLanguage }
    "src/lib/folders/color-keys" --> "src/components/dashboard-nav" { folderColorKeys }
    "src/lib/i18n/types.d" --> "src/components/dashboard-nav" { TranslationKey }
    src.components.icons --> "src/components/dashboard-nav" {
        Archive,
        BellOff,
        CalendarClock,
        Clock,
        FileText,
        Folder,
        Inbox,
        MailPlus,
        Plus,
        Send,
        ShieldAlert,
        Star,
        Tag,
        Trash2,
    }
    "src/components/mailbox-provider" --> "src/components/dashboard-nav" { useSelectedMailbox }
    src.components.ui.button --> "src/components/dashboard-nav" { Button }
    src.components.ui.dialog --> "src/components/dashboard-nav" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
        DialogTrigger,
    }
    src.components.ui.input --> "src/components/dashboard-nav" { Input }
    src.components.ui.label --> "src/components/dashboard-nav" { Label }
    "src/hooks/use-message-counts" --> "src/components/dashboard-nav" { useMessageCounts }
    "src/lib/promotions/ui-utils" --> "src/components/dashboard-nav" { hasActivePromotions }
    src.lib.auth.client --> "src/components/dashboard-nav" { AUTH_SESSION_CHANGED_EVENT, authFetch }
    src.lib.folders.client --> "src/components/dashboard-nav" {
        getMailboxFolders,
        invalidateFolderCache,
    }
    src.lib.folders.colors --> "src/components/dashboard-nav" {
        DEFAULT_FOLDER_COLOR,
        FOLDER_COLOR_OPTIONS,
    }
    "src/lib/folders/types.d" --> "src/components/dashboard-nav" { FolderColor }
    src.lib.utils --> "src/components/dashboard-nav" { cn }
    "src/components/components-nav" --> "src/components/dashboard-nav" { NavItem }
    "src/components/components-nav-types.d" --> "src/components/dashboard-nav" { NavLink }
    "src/components/dashboard-nav-types.d" --> "src/components/dashboard-nav" { CustomFolder }
    "src/components/dashboard-nav-utils" --> "src/components/dashboard-nav" {
        getFolderNavCount,
        moveMessagesToCustomFolder,
        moveMessagesToSystemFolder,
    }
    "src/components/nav-section-header" --> "src/components/dashboard-nav" {
        NavSectionHeader,
        useSectionOpen,
    }
    "src/components/reorderable-list" --> "src/components/dashboard-nav" { ReorderableList }
    "src/components/reorderable-list-utils" --> "src/components/dashboard-nav" {
        readStorage,
        writeStorage,
    }
    "src/components/sidebar-footer" --> "src/components/dashboard-nav" { SidebarFooter }
    "src/components/sidebar-header" --> "src/components/dashboard-nav" { SidebarHeader }
    "src/components/sidebar-scaffold" --> "src/components/dashboard-nav" { SidebarScaffold }
    "src/components/sidebar-state" --> "src/components/dashboard-nav" { useSidebar }
    "src/hooks/types.d" --> "src/components/dashboard-nav-utils" { MessageCounts, MessageFolder }
    src.lib.messages.actions.client --> "src/components/dashboard-nav-utils" {
        performMessageAction,
    }
    src.lib.utils --> "src/components/reorderable-list" { cn }
    "src/components/reorderable-list-utils" --> "src/components/reorderable-list" {
        moveItem,
        readStorage,
        resolveLayout,
        writeStorage,
    }
    "src/components/reorderable-list-types.d" --> "src/components/reorderable-list" {
        ReorderableDrag,
        ReorderableDropTarget,
        ReorderableLayout,
        ReorderableListProps,
    }
    "src/lib/push/app-badge" --> "src/hooks/use-app-badge" { setAppBadgeCount }
    "src/hooks/use-message-counts" --> "src/hooks/use-app-badge" { useMessageCounts }
    "src/components/language-provider" --> "src/components/messages/undo-toasts" { useLanguage }
    src.components.icons --> "src/components/messages/undo-toasts" { Loader2 }
    src.lib.messages.actions.client --> "src/components/messages/undo-toasts" {
        MessageActionRequestError,
        undoMessageAction,
    }
    "src/lib/messages/actions/types.d" --> "src/components/messages/undo-toasts" {
        MessageActionSkipped,
        ReversibleMessageAction,
    }
    "src/lib/messages/actions/undo-store" --> "src/components/messages/undo-toasts" {
        UndoToastAnnouncement,
        UndoToastEntry,
        UndoToastFailure,
        UndoToastFailureKind,
        beginUndoToast,
        completeUndoToast,
        dismissUndoToast,
        failUndoToast,
        getUndoAnnouncements,
        getUndoToasts,
        hideUndoToast,
        partialUndoToast,
        pauseUndoToast,
        pauseUndoToasts,
        resumeUndoToast,
        resumeUndoToasts,
        subscribeUndoToasts,
    }
    src.lib.i18n.utils --> "src/components/messages/undo-toasts" { Translator }
    "src/lib/i18n/types.d" --> "src/components/messages/undo-toasts" { TranslationKey }
    src.lib.utils --> "src/components/messages/undo-toasts" { cn }
    src.components.icons --> "src/components/messages/promotion-toast" { Loader2 }
    "src/components/language-provider" --> "src/components/messages/promotion-toast" { useLanguage }
    "src/lib/promotions/move-client" --> "src/components/messages/promotion-toast" {
        applyAlwaysForSender,
    }
    "src/lib/promotions/move-utils" --> "src/components/messages/promotion-toast" {
        isToastPaused,
        remainingAfter,
    }
    src.lib.utils --> "src/components/messages/promotion-toast" { cn }
    "src/components/messages/promotion-toast-store" --> "src/components/messages/promotion-toast" {
        PromotionToastEntry,
        dismissPromotionToast,
        getPromotionToast,
        subscribePromotionToast,
    }
    "src/components/route-loading-bar" --> "src/app/(dashboard)/loading" { RouteLoadingBar }
    "src/app/(dashboard)/inbox/[messageId]/page" --> "src/app/(dashboard)/promotions/[messageId]/page" {
        default,
    }
    "src/components/messages/message-folder-configs" --> "src/app/(dashboard)/promotions/layout" {
        promotionsFolderConfig,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/promotions/layout" {
        MessageSplitLayout,
    }
    "src/app/(dashboard)/inbox/[messageId]/page" --> "src/app/(dashboard)/scheduled/[messageId]/page" {
        default,
    }
    "src/components/messages/message-folder-configs" --> "src/app/(dashboard)/scheduled/layout" {
        scheduledFolderConfig,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/scheduled/layout" {
        MessageSplitLayout,
    }
    "src/app/(dashboard)/inbox/[messageId]/page" --> "src/app/(dashboard)/sent/[messageId]/page" {
        default,
    }
    "src/components/messages/message-folder-configs" --> "src/app/(dashboard)/sent/layout" {
        sentFolderConfig,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/sent/layout" {
        MessageSplitLayout,
    }
    "src/app/(dashboard)/inbox/[messageId]/page" --> "src/app/(dashboard)/snoozed/[messageId]/page" {
        default,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/snoozed/layout" {
        MessageSplitLayout,
    }
    "src/components/messages/message-folder-configs" --> "src/app/(dashboard)/snoozed/layout" {
        snoozedFolderConfig,
    }
    "src/app/(dashboard)/inbox/[messageId]/page" --> "src/app/(dashboard)/spam/[messageId]/page" {
        default,
    }
    "src/components/messages/message-folder-configs" --> "src/app/(dashboard)/spam/layout" {
        spamFolderConfig,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/spam/layout" {
        MessageSplitLayout,
    }
    "src/app/(dashboard)/inbox/[messageId]/page" --> "src/app/(dashboard)/starred/[messageId]/page" {
        default,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/starred/layout" {
        MessageSplitLayout,
    }
    "src/components/messages/message-folder-configs" --> "src/app/(dashboard)/starred/layout" {
        starredFolderConfig,
    }
    "src/components/subscriptions/subscriptions-page" --> "src/app/(dashboard)/subscriptions/page" {
        SubscriptionsPage,
    }
    src.components.icons --> "src/components/subscriptions/subscriptions-page" {
        ChevronLeft,
        ChevronRight,
    }
    "src/components/language-provider" --> "src/components/subscriptions/subscriptions-page" {
        useLanguage,
    }
    "src/components/mailbox-provider" --> "src/components/subscriptions/subscriptions-page" {
        useSelectedMailbox,
    }
    src.components.messages.utils --> "src/components/subscriptions/subscriptions-page" {
        getMailboxAddress,
    }
    "src/components/message-actions/utils" --> "src/components/subscriptions/subscriptions-page" {
        blockMessageContact,
        openUnsubscribeUrl,
    }
    "src/components/messages/unsubscribe-button-utils" --> "src/components/subscriptions/subscriptions-page" {
        requestUnsubscribe,
    }
    src.components.ui.button --> "src/components/subscriptions/subscriptions-page" { Button }
    "src/components/ui/confirm-dialog" --> "src/components/subscriptions/subscriptions-page" {
        confirmDestructive,
        confirmDialog,
    }
    src.components.ui.select --> "src/components/subscriptions/subscriptions-page" { Select }
    src.components.ui.skeleton --> "src/components/subscriptions/subscriptions-page" { Skeleton }
    "src/hooks/use-message-counts" --> "src/components/subscriptions/subscriptions-page" {
        useMessageCounts,
    }
    "src/lib/messages/change-events" --> "src/components/subscriptions/subscriptions-page" {
        dispatchMessagesChanged,
    }
    "src/lib/promotions/move-utils" --> "src/components/subscriptions/subscriptions-page" {
        CopyDescriptor,
    }
    "src/lib/promotions/subscriptions-client" --> "src/components/subscriptions/subscriptions-page" {
        fetchSubscriptions,
        previewSenderTrash,
        saveSenderCategory,
        trashSender,
    }
    "src/lib/promotions/subscriptions-ui-utils" --> "src/components/subscriptions/subscriptions-page" {
        SUBSCRIPTIONS_PAGE_SIZE,
        categoryResultCopy,
        categoryToApi,
        getPager,
        getRowView,
        mailboxesWithPromotions,
        pageBackOffset,
        pickMailboxId,
        trashConfirmCopy,
        trashResultCopy,
    }
    "src/lib/promotions/subscriptions-ui-types.d" --> "src/components/subscriptions/subscriptions-page" {
        SubscriptionCategory,
        SubscriptionRowAction,
        SubscriptionRowData,
    }
    "src/components/subscriptions/subscription-parts" --> "src/components/subscriptions/subscriptions-page" {
        CategoryControl,
        LastReceived,
        MessageCount,
        ReadRate,
        RowActions,
        SenderCell,
    }
    src.lib.auth.client --> "src/lib/promotions/subscriptions-client" { authFetch }
    "src/lib/promotions/subscriptions-ui-types.d" --> "src/lib/promotions/subscriptions-client" {
        SubscriptionRowData,
        TrashPreview,
    }
    "src/lib/promotions/move-utils" --> "src/lib/promotions/subscriptions-ui-utils" {
        CopyDescriptor,
        senderResultCopy,
    }
    "src/lib/promotions/ui-utils" --> "src/lib/promotions/subscriptions-ui-utils" {
        canManagePromotions,
    }
    "src/lib/promotions/subscriptions-ui-types.d" --> "src/lib/promotions/subscriptions-ui-utils" {
        SubscriptionCategory,
        SubscriptionRowData,
        SubscriptionRowView,
        SubscriptionTrashAction,
        TrashPreview,
    }
    "src/lib/promotions/subscriptions-utils" --> "src/lib/promotions/subscriptions-ui-utils" {
        SUBSCRIPTIONS_PAGE_SIZE,
    }
    src.components.icons --> "src/components/subscriptions/subscription-parts" {
        Ban,
        BellOff,
        MoreVertical,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/subscriptions/subscription-parts" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/subscriptions/subscription-parts" { Button }
    src.components.ui.select --> "src/components/subscriptions/subscription-parts" { Select }
    "src/lib/promotions/subscriptions-ui-utils" --> "src/components/subscriptions/subscription-parts" {
        daysSince,
        formatReadRate,
    }
    "src/lib/promotions/subscriptions-ui-types.d" --> "src/components/subscriptions/subscription-parts" {
        SubscriptionCategory,
        SubscriptionRowAction,
    }
    src.lib.time.utils --> "src/components/subscriptions/subscription-parts" { formatUserDate }
    "src/lib/i18n/types.d" --> "src/components/subscriptions/subscription-parts" { TranslationKey }
    "src/components/subscriptions/subscription-parts-types.d" --> "src/components/subscriptions/subscription-parts" {
        SubscriptionRowProps,
    }
    "src/app/(dashboard)/inbox/[messageId]/page" --> "src/app/(dashboard)/trash/[messageId]/page" {
        default,
    }
    "src/components/messages/message-folder-configs" --> "src/app/(dashboard)/trash/layout" {
        trashFolderConfig,
    }
    "src/components/messages/message-split-layout" --> "src/app/(dashboard)/trash/layout" {
        MessageSplitLayout,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(drive)/drive-bulk-actions" {
        confirmDestructive,
    }
    src.components.icons --> "src/app/(drive)/drive-bulk-actions" {
        Folder,
        FolderInput,
        FolderPlus,
        HardDrive,
        RotateCcw,
        Trash2,
        X,
    }
    "src/components/language-provider" --> "src/app/(drive)/drive-bulk-actions" { useLanguage }
    src.components.ui.button --> "src/app/(drive)/drive-bulk-actions" { Button }
    src.lib.auth.client --> "src/app/(drive)/drive-bulk-actions" { authFetch }
    "src/lib/drive/types.d" --> "src/app/(drive)/drive-bulk-actions" { DriveItemDto }
    src.lib.auth.client --> "src/app/(drive)/drive-cache" { AUTH_SESSION_CHANGED_EVENT }
    "src/lib/drive/types.d" --> "src/app/(drive)/drive-cache" {
        DriveCrumb,
        DriveItemDto,
        DriveRole,
    }
    "src/components/language-provider" --> "src/app/(drive)/drive-columns" { useLanguage }
    src.lib.i18n.utils --> "src/app/(drive)/drive-drag" { Translator }
    "src/lib/drive/types.d" --> "src/app/(drive)/drive-drag" { DriveItemDto }
    src.lib.drive.utils --> "src/app/(drive)/drive-drag" { canEditDrive }
    "src/app/(drive)/drive-bulk-actions" --> "src/app/(drive)/drive-drag" { attachmentAction, bulk }
    "src/app/(drive)/drive-events" --> "src/app/(drive)/drive-drag" { DRIVE_REFRESH_EVENT }
    src.components.icons --> "src/app/(drive)/drive-nav" {
        ChevronRight,
        Folder,
        FolderPlus,
        HardDrive,
        Paperclip,
        Plus,
        Trash2,
        UploadCloud,
        UsersRound,
    }
    "src/components/language-provider" --> "src/app/(drive)/drive-nav" { useLanguage }
    src.components.ui.button --> "src/app/(drive)/drive-nav" { Button }
    src.components.ui.dialog --> "src/app/(drive)/drive-nav" {
        Dialog,
        DialogContent,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/app/(drive)/drive-nav" { Input }
    "src/components/sidebar-footer" --> "src/app/(drive)/drive-nav" { PoweredBy }
    "src/components/sidebar-state" --> "src/app/(drive)/drive-nav" { useSidebar }
    src.lib.auth.client --> "src/app/(drive)/drive-nav" { authFetch }
    src.lib.drive.utils --> "src/app/(drive)/drive-nav" { formatDriveSize }
    "src/app/(drive)/drive-events" --> "src/app/(drive)/drive-nav" {
        DRIVE_FOLDERS_EVENT,
        DRIVE_NEW_FOLDER_EVENT,
        DRIVE_REFRESH_EVENT,
        DRIVE_STORAGE_EVENT,
        DRIVE_UPLOAD_EVENT,
        DriveStorageDetail,
    }
    "src/app/(drive)/drive-drag" --> "src/app/(drive)/drive-nav" {
        DriveDropTarget,
        canDropDrive,
        driveDropHandlers,
    }
    "src/components/language-provider" --> "src/app/(drive)/drive-owner-avatar" { useLanguage }
    src.components.ui.tooltip --> "src/app/(drive)/drive-owner-avatar" { Tooltip }
    "src/lib/avatar-colors" --> "src/app/(drive)/drive-owner-avatar" { getAvatarColorStyle }
    "src/lib/drive/types.d" --> "src/app/(drive)/drive-owner-avatar" { DriveItemDto }
    src.components.icons --> "src/app/(drive)/drive-preview" { Download }
    "src/components/language-provider" --> "src/app/(drive)/drive-preview" { useLanguage }
    "src/app/(drive)/drive-utils" --> "src/app/(drive)/drive-preview" { canPreview }
    src.components.icons --> "src/app/(drive)/drive-utils" {
        File,
        FileArchive,
        FileAudio,
        FileCode,
        FileImage,
        FileSpreadsheet,
        FileText,
        FileVideo,
        Folder,
        Presentation,
    }
    "src/lib/drive/types.d" --> "src/app/(drive)/drive-utils" { DriveItemDto }
    src.components.icons --> "src/app/(drive)/drive-share-dialog" { Copy, Link2, X }
    "src/components/language-provider" --> "src/app/(drive)/drive-share-dialog" { useLanguage }
    src.components.ui.button --> "src/app/(drive)/drive-share-dialog" { Button }
    src.components.ui.dialog --> "src/app/(drive)/drive-share-dialog" {
        Dialog,
        DialogContent,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/app/(drive)/drive-share-dialog" { Input }
    src.lib.auth.client --> "src/app/(drive)/drive-share-dialog" { authFetch }
    "src/lib/drive/types.d" --> "src/app/(drive)/drive-share-dialog" {
        DriveItemDto,
        DriveShareDto,
        DriveShareRole,
    }
    src.components.ui.select --> "src/app/(drive)/drive-share-dialog" { Select }
    src.components.icons --> "src/app/(drive)/drive-type-filter" { Check, ListFilter }
    "src/components/language-provider" --> "src/app/(drive)/drive-type-filter" { useLanguage }
    "src/lib/drive/category-names" --> "src/app/(drive)/drive-type-filter" {
        DRIVE_CATEGORIES,
        DriveCategory,
    }
    src.components.icons --> "src/app/(drive)/drive-upload-panel" { AlertCircle, CheckCircle2, X }
    "src/components/language-provider" --> "src/app/(drive)/drive-upload-panel" { useLanguage }
    "src/app/(drive)/drive-upload-types.d" --> "src/app/(drive)/drive-upload-panel" {
        DriveUploadEntry,
    }
    "src/components/ui/confirm-dialog" --> "src/app/(drive)/drive/page" { confirmDestructive }
    "src/components/header-search" --> "src/app/(drive)/drive/page" { HeaderSearch }
    src.components.icons --> "src/app/(drive)/drive/page" {
        ArrowDown,
        ArrowUp,
        ChevronRight,
        Download,
        ExternalLink,
        Mail,
        MoreVertical,
        Pencil,
        RotateCcw,
        Share2,
        Trash2,
        UploadCloud,
        X,
    }
    "src/components/language-provider" --> "src/app/(drive)/drive/page" { useLanguage }
    src.components.ui.button --> "src/app/(drive)/drive/page" { Button }
    src.components.ui.dialog --> "src/app/(drive)/drive/page" {
        Dialog,
        DialogContent,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/app/(drive)/drive/page" { Input }
    src.lib.auth.client --> "src/app/(drive)/drive/page" { authFetch }
    src.lib.drive.utils --> "src/app/(drive)/drive/page" {
        DRIVE_MAX_FILE_BYTES,
        canEditDrive,
        formatDriveSize,
    }
    "src/lib/drive/types.d" --> "src/app/(drive)/drive/page" { DriveItemDto }
    "src/app/(drive)/drive-events" --> "src/app/(drive)/drive/page" {
        DRIVE_FOLDERS_EVENT,
        DRIVE_NEW_FOLDER_EVENT,
        DRIVE_REFRESH_EVENT,
        DRIVE_STORAGE_EVENT,
        DRIVE_UPLOAD_EVENT,
    }
    "src/app/(drive)/drive-preview" --> "src/app/(drive)/drive/page" { DrivePreviewBody }
    "src/app/(drive)/drive-share-dialog" --> "src/app/(drive)/drive/page" { DriveShareDialog }
    "src/app/(drive)/drive-utils" --> "src/app/(drive)/drive/page" {
        DriveSortKey,
        driveFileUrl,
        driveIconFor,
        emailUrl,
        sortDriveItems,
    }
    "src/app/(drive)/drive-bulk-actions" --> "src/app/(drive)/drive/page" { DriveBulkActions }
    src.components.ui.checkbox --> "src/app/(drive)/drive/page" { Checkbox }
    "src/app/(drive)/drive-owner-avatar" --> "src/app/(drive)/drive/page" { DriveOwnerAvatar }
    "src/app/(drive)/drive-columns" --> "src/app/(drive)/drive/page" {
        ColumnResizeHandle,
        useDriveColumns,
    }
    "src/app/(drive)/drive-type-filter" --> "src/app/(drive)/drive/page" { DriveTypeFilter }
    "src/lib/drive/category-names" --> "src/app/(drive)/drive/page" {
        DriveCategory,
        isDriveCategory,
    }
    "src/app/(drive)/drive-upload" --> "src/app/(drive)/drive/page" { uploadDriveFile }
    "src/app/(drive)/drive-upload-types.d" --> "src/app/(drive)/drive/page" { DriveUploadEntry }
    "src/app/(drive)/drive-upload-panel" --> "src/app/(drive)/drive/page" { DriveUploadPanel }
    "src/app/(drive)/drive-cache" --> "src/app/(drive)/drive/page" {
        DriveListing,
        clearDriveListings,
        readDriveListing,
        saveDriveListing,
    }
    src.components.ui.skeleton --> "src/app/(drive)/drive/page" { Skeleton }
    "src/app/(drive)/drive-drag" --> "src/app/(drive)/drive/page" {
        canDropDrive,
        driveDropHandlers,
        endDriveDrag,
        isDriveDraggable,
        startDriveDrag,
    }
    "src/components/skip-to-content" --> "src/app/(drive)/layout" { SkipToContent }
    "src/components/auth/auth-guard" --> "src/app/(drive)/layout" { AuthGuard }
    "src/components/compose/compose-context" --> "src/app/(drive)/layout" { ComposeProvider }
    "src/components/license-indicator" --> "src/app/(drive)/layout" { LicenseIndicator }
    "src/components/mail-search/mail-search-context" --> "src/app/(drive)/layout" {
        MailSearchProvider,
    }
    "src/components/mailbox-provider" --> "src/app/(drive)/layout" { MailboxProvider }
    "src/components/mailbox-selector" --> "src/app/(drive)/layout" { MailboxSelector }
    "src/components/sidebar-aside" --> "src/app/(drive)/layout" { MobileMenuButton, SidebarAside }
    "src/components/sidebar-header" --> "src/app/(drive)/layout" { SidebarHeader }
    "src/components/sidebar-resize-boundary" --> "src/app/(drive)/layout" { SidebarResizeBoundary }
    "src/components/sidebar-state" --> "src/app/(drive)/layout" { SidebarProvider, useSidebar }
    src.components.shortcuts.index --> "src/app/(drive)/layout" { ShortcutsProvider }
    "src/app/(drive)/drive-nav" --> "src/app/(drive)/layout" { DriveNav }
    "src/components/route-title" --> "src/app/(drive)/layout" { RouteTitle }
    "src/components/skip-to-content" --> "src/app/(settings)/layout" { SkipToContent }
    src.components.icons --> "src/app/(settings)/layout" { HelpCircle }
    "src/components/auth/auth-guard" --> "src/app/(settings)/layout" { AuthGuard }
    "src/components/compose/compose-context" --> "src/app/(settings)/layout" { ComposeProvider }
    "src/components/compose/floating-composer" --> "src/app/(settings)/layout" { FloatingComposer }
    "src/components/mail-search/mail-search-input" --> "src/app/(settings)/layout" {
        MailSearchInput,
    }
    "src/components/mail-search/mail-search-context" --> "src/app/(settings)/layout" {
        MailSearchProvider,
    }
    "src/components/mailbox-provider" --> "src/app/(settings)/layout" { MailboxProvider }
    "src/components/mailbox-selector" --> "src/app/(settings)/layout" { MailboxSelector }
    "src/components/license-indicator" --> "src/app/(settings)/layout" { LicenseIndicator }
    "src/components/dashboard-nav" --> "src/app/(settings)/layout" { DashboardNav }
    "src/components/sidebar-state" --> "src/app/(settings)/layout" { SidebarProvider }
    src.components.shortcuts.index --> "src/app/(settings)/layout" { ShortcutsProvider }
    "src/components/sidebar-aside" --> "src/app/(settings)/layout" {
        MobileMenuButton,
        SidebarAside,
    }
    "src/components/route-title" --> "src/app/(settings)/layout" { RouteTitle }
    "src/components/settings/account-settings" --> "src/app/(settings)/settings/account/page" {
        AccountSettings,
    }
    "src/components/language-provider" --> "src/components/settings/account-settings" {
        useLanguage,
    }
    "src/components/language-selector" --> "src/components/settings/account-settings" {
        LanguageSelector,
    }
    src.components.ui.skeleton --> "src/components/settings/account-settings" { Skeleton }
    "src/components/settings/mailbox-signature-form" --> "src/components/settings/account-settings" {
        MailboxSignatureForm,
    }
    "src/components/settings/profile-form" --> "src/components/settings/account-settings" {
        ProfileForm,
    }
    "src/components/settings/time-zone-form" --> "src/components/settings/account-settings" {
        TimeZoneForm,
    }
    "src/components/settings/types.d" --> "src/components/settings/account-settings" {
        AccountSettingsResponse,
    }
    src.components.settings.utils --> "src/components/settings/account-settings" {
        loadAccountSettings,
    }
    "src/components/language-provider" --> "src/components/settings/mailbox-signature-form" {
        useLanguage,
    }
    "src/components/mailbox-provider" --> "src/components/settings/mailbox-signature-form" {
        useSelectedMailbox,
    }
    "src/components/compose/rich-text-utils" --> "src/components/settings/mailbox-signature-form" {
        isHtmlSignature,
    }
    "src/components/messages/email-html-renderer" --> "src/components/settings/mailbox-signature-form" {
        EmailHtmlRenderer,
    }
    src.components.ui.button --> "src/components/settings/mailbox-signature-form" { Button }
    src.components.ui.label --> "src/components/settings/mailbox-signature-form" { Label }
    src.components.ui.textarea --> "src/components/settings/mailbox-signature-form" { Textarea }
    src.components.settings.utils --> "src/components/settings/mailbox-signature-form" {
        updateMailboxSignature,
    }
    "src/components/mailbox-provider" --> src.components.settings.utils { MailboxOption }
    "src/components/mailbox-provider-utils" --> src.components.settings.utils {
        clearMailboxesCache,
    }
    src.lib.auth.client --> src.components.settings.utils { authFetch }
    "src/lib/http/client-error" --> src.components.settings.utils { requestError }
    "src/components/settings/types.d" --> src.components.settings.utils {
        AccountSettingsResponse,
        ChangePasswordResponse,
        CurrentMailboxFormResponse,
        MailboxAutoReplyResponse,
        MailboxAutoReplySettings,
        MailboxSignatureResponse,
        MfaEnrollmentResponse,
        MfaRecoveryCodesResponse,
    }
    "src/components/language-provider" --> "src/components/settings/profile-form" { useLanguage }
    "src/components/mailbox-provider" --> "src/components/settings/profile-form" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/components/settings/profile-form" { Button }
    src.components.ui.input --> "src/components/settings/profile-form" { Input }
    src.components.ui.label --> "src/components/settings/profile-form" { Label }
    src.lib.auth.client --> "src/components/settings/profile-form" { authFetch }
    "src/lib/profile/name-client" --> "src/components/settings/profile-form" {
        dispatchProfileNameChanged,
    }
    "src/components/settings/inbox-switcher" --> "src/components/settings/profile-form" {
        InboxSwitcher,
    }
    "src/components/settings/security-status-store" --> "src/components/settings/profile-form" {
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/components/settings/profile-form" {
        StepUpDialog,
    }
    "src/components/settings/profile-avatar-form" --> "src/components/settings/profile-form" {
        ProfileAvatarForm,
    }
    "src/components/settings/types.d" --> "src/components/settings/profile-form" {
        ProfileFormProps,
        ProfileFormResponse,
    }
    src.components.settings.utils --> "src/components/settings/profile-form" {
        getMailboxAddress,
        updateCurrentMailboxName,
    }
    src.components.icons --> "src/components/settings/inbox-switcher" {
        Check,
        ChevronDown,
        UsersRound,
    }
    "src/components/use-dismissible" --> "src/components/settings/inbox-switcher" { useDismissible }
    "src/components/language-provider" --> "src/components/settings/inbox-switcher" { useLanguage }
    "src/components/mailbox-provider" --> "src/components/settings/inbox-switcher" {
        MailboxOption,
        useSelectedMailbox,
    }
    "src/components/progressive-avatar-image" --> "src/components/settings/inbox-switcher" {
        ProgressiveAvatarImage,
    }
    "src/components/mailbox-selector-utils" --> "src/components/settings/inbox-switcher" {
        getAccountInitial,
        getMailboxAddress,
        getMailboxName,
    }
    "src/lib/avatar-colors" --> "src/components/settings/inbox-switcher" { getAvatarColorStyle }
    src.components.icons --> "src/components/settings/profile-avatar-form" {
        Camera,
        LoaderCircle,
        User,
    }
    src.lib.auth.client --> "src/components/settings/profile-avatar-form" { authFetch }
    "src/lib/avatar-colors" --> "src/components/settings/profile-avatar-form" {
        getAvatarColorStyle,
    }
    "src/lib/profile/avatar-client" --> "src/components/settings/profile-avatar-form" {
        dispatchProfileAvatarChanged,
        getProfileAvatarUrl,
    }
    "src/lib/mailboxes/avatar-client" --> "src/components/settings/profile-avatar-form" {
        dispatchMailboxAvatarChanged,
    }
    "src/components/language-provider" --> "src/components/settings/profile-avatar-form" {
        useLanguage,
    }
    src.components.ui.input --> "src/components/settings/profile-avatar-form" { Input }
    "src/components/progressive-avatar-image" --> "src/components/settings/profile-avatar-form" {
        ProgressiveAvatarImage,
    }
    "src/components/settings/types.d" --> "src/components/settings/profile-avatar-form" {
        ProfileAvatarFormProps,
        ProfileAvatarSessionResponse,
    }
    "src/components/settings/profile-avatar-form-utils" --> "src/components/settings/profile-avatar-form" {
        PROFILE_AVATAR_ACCEPT,
        getMailboxProfileAvatarUrl,
        uploadMailboxProfileAvatar,
        uploadProfileAvatar,
        validateProfileAvatar,
    }
    "src/components/language-provider" --> "src/components/settings/time-zone-form" { useLanguage }
    src.components.ui.button --> "src/components/settings/time-zone-form" { Button }
    src.components.ui.input --> "src/components/settings/time-zone-form" { Input }
    src.components.ui.label --> "src/components/settings/time-zone-form" { Label }
    src.lib.time.client --> "src/components/settings/time-zone-form" { saveUserTimeZonePreference }
    "src/components/settings/time-zone-form-utils" --> "src/components/settings/time-zone-form" {
        formatCurrentTimeInZone,
        listTimeZones,
        updateUserTimeZone,
    }
    "src/components/settings/time-zone-form-types.d" --> "src/components/settings/time-zone-form" {
        TimeZoneFormProps,
    }
    src.lib.auth.client --> "src/components/settings/time-zone-form-utils" { authFetch }
    src.lib.time.utils --> "src/components/settings/time-zone-form-utils" { isValidTimeZone }
    "src/components/settings/time-zone-form-types.d" --> "src/components/settings/time-zone-form-utils" {
        TimeZoneUpdateResponse,
    }
    "src/components/settings/api-keys-settings" --> "src/app/(settings)/settings/api-keys/page" {
        ApiKeysSettings,
    }
    "src/components/page-header-utils" --> "src/components/settings/api-keys-settings" {
        mobilePrimaryActionAboveNavClass,
    }
    "src/components/ui/confirm-dialog" --> "src/components/settings/api-keys-settings" {
        confirmDestructive,
    }
    src.components.icons --> "src/components/settings/api-keys-settings" {
        Copy,
        KeyRound,
        Plus,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/settings/api-keys-settings" {
        useLanguage,
    }
    "src/components/mailbox-provider" --> "src/components/settings/api-keys-settings" {
        useSelectedMailbox,
    }
    src.components.ui.badge --> "src/components/settings/api-keys-settings" { Badge }
    src.components.ui.button --> "src/components/settings/api-keys-settings" { Button }
    src.components.ui.checkbox --> "src/components/settings/api-keys-settings" { Checkbox }
    src.components.ui.dialog --> "src/components/settings/api-keys-settings" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
        DialogTrigger,
    }
    src.components.ui.input --> "src/components/settings/api-keys-settings" { Input }
    src.components.ui.label --> "src/components/settings/api-keys-settings" { Label }
    src.components.ui.list --> "src/components/settings/api-keys-settings" { List, ListRow }
    "src/components/page-skeletons" --> "src/components/settings/api-keys-settings" {
        SectionRowSkeleton,
    }
    src.lib.time.utils --> "src/components/settings/api-keys-settings" { formatUserDate }
    "src/components/settings/mcp-agent-instructions" --> "src/components/settings/api-keys-settings" {
        McpAgentInstructions,
    }
    src.lib.api.scopes --> "src/components/settings/api-keys-settings" { ApiKeyScope }
    "src/lib/http/client-error" --> "src/components/settings/api-keys-settings" {
        ClientRequestError,
    }
    "src/components/settings/api-keys-settings-types.d" --> "src/components/settings/api-keys-settings" {
        ManagedApiKey,
        McpKeyScope,
    }
    "src/components/settings/security-status-store" --> "src/components/settings/api-keys-settings" {
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/components/settings/api-keys-settings" {
        StepUpDialog,
    }
    "src/components/settings/api-keys-settings-utils" --> "src/components/settings/api-keys-settings" {
        MCP_KEY_SCOPES,
        STANDARD_KEY_SCOPES,
        createManagedApiKey,
        keyPermissions,
        loadManagedApiKeys,
        revokeManagedApiKey,
    }
    "src/lib/i18n/types.d" --> "src/components/settings/api-keys-settings-utils" { TranslationKey }
    src.lib.auth.client --> "src/components/settings/api-keys-settings-utils" { authFetch }
    "src/lib/http/client-error" --> "src/components/settings/api-keys-settings-utils" {
        requestError,
    }
    src.lib.api.scopes --> "src/components/settings/api-keys-settings-utils" { ApiKeyScope }
    "src/components/settings/api-keys-settings-types.d" --> "src/components/settings/api-keys-settings-utils" {
        ManagedApiKey,
        McpKeyScope,
    }
    src.lib.i18n.server --> "src/app/(settings)/settings/app-passwords/page" { getServerTranslator }
    "src/components/settings/app-passwords-settings" --> "src/app/(settings)/settings/app-passwords/page" {
        AppPasswordsSettings,
    }
    src.components.icons --> "src/components/settings/app-passwords-settings" { Copy, KeyRound }
    "src/components/language-provider" --> "src/components/settings/app-passwords-settings" {
        useLanguage,
    }
    "src/components/mailbox-provider" --> "src/components/settings/app-passwords-settings" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/components/settings/app-passwords-settings" { Button }
    src.components.ui.checkbox --> "src/components/settings/app-passwords-settings" { Checkbox }
    "src/components/ui/confirm-dialog" --> "src/components/settings/app-passwords-settings" {
        confirmDestructive,
    }
    src.components.ui.input --> "src/components/settings/app-passwords-settings" { Input }
    src.components.ui.label --> "src/components/settings/app-passwords-settings" { Label }
    "src/lib/http/client-error" --> "src/components/settings/app-passwords-settings" {
        ClientRequestError,
    }
    src.lib.time.utils --> "src/components/settings/app-passwords-settings" { formatUserDate }
    "src/components/settings/app-passwords-types.d" --> "src/components/settings/app-passwords-settings" {
        AppPasswordList,
        AppPasswordSummary,
        CreatedAppPassword,
    }
    "src/components/settings/app-passwords-utils" --> "src/components/settings/app-passwords-settings" {
        appPasswordProtocolName,
        createAppPassword,
        groupAppPassword,
        loadAppPasswords,
        revokeAppPassword,
    }
    "src/components/settings/sign-in-qr-utils" --> "src/components/settings/app-passwords-settings" {
        buildSignInQrPayload,
    }
    "src/components/settings/security-status-store" --> "src/components/settings/app-passwords-settings" {
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/components/settings/app-passwords-settings" {
        StepUpDialog,
    }
    src.lib.auth.client --> "src/components/settings/app-passwords-utils" { authFetch }
    "src/lib/http/client-error" --> "src/components/settings/app-passwords-utils" { requestError }
    "src/components/settings/app-passwords-types.d" --> "src/components/settings/app-passwords-utils" {
        AppPasswordList,
        CreatedAppPassword,
        NewAppPassword,
    }
    src.components.icons --> "src/app/(settings)/settings/export/page" { Download }
    "src/components/language-provider" --> "src/app/(settings)/settings/export/page" { useLanguage }
    "src/components/mailbox-provider" --> "src/app/(settings)/settings/export/page" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/app/(settings)/settings/export/page" { Button }
    "src/app/(settings)/settings/export/types.d" --> "src/app/(settings)/settings/export/page" {
        ExportState,
    }
    "src/app/(settings)/settings/export/utils" --> "src/app/(settings)/settings/export/page" {
        exportMailbox,
    }
    src.lib.auth.client --> "src/app/(settings)/settings/export/utils" { authFetch }
    src.components.icons --> "src/app/(settings)/settings/import/page" { Folder, Server, Upload }
    "src/components/language-provider" --> "src/app/(settings)/settings/import/page" { useLanguage }
    "src/lib/i18n/types.d" --> "src/app/(settings)/settings/import/page" { TranslationKey }
    "src/components/mailbox-provider" --> "src/app/(settings)/settings/import/page" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/app/(settings)/settings/import/page" { Button }
    src.components.ui.checkbox --> "src/app/(settings)/settings/import/page" { Checkbox }
    src.components.ui.card --> "src/app/(settings)/settings/import/page" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    src.components.ui.input --> "src/app/(settings)/settings/import/page" { Input }
    src.components.ui.label --> "src/app/(settings)/settings/import/page" { Label }
    src.components.ui.select --> "src/app/(settings)/settings/import/page" { Select }
    "src/components/settings/import-jobs" --> "src/app/(settings)/settings/import/page" {
        ImportJobs,
    }
    "src/components/settings/import-messages-utils" --> "src/app/(settings)/settings/import/page" {
        importMessageFiles,
    }
    "src/components/settings/takeout-data-import" --> "src/app/(settings)/settings/import/page" {
        TakeoutDataImport,
    }
    "src/components/settings/takeout-import" --> "src/app/(settings)/settings/import/page" {
        TakeoutImport,
    }
    "src/app/(settings)/settings/import/types.d" --> "src/app/(settings)/settings/import/page" {
        ImapFormState,
        ImportProgress,
        ImportSourceItem,
        ImportSourceSection,
        ImportTab,
    }
    "src/app/(settings)/settings/import/utils" --> "src/app/(settings)/settings/import/page" {
        ensureImportDestination,
        fetchImapFolders,
        filterCustomImapFolders,
        getFileImportSource,
        getFolderImportSource,
        getSelectedImportSources,
        importSourceOptions,
        resolveImapSourceFolder,
        startImapImport,
    }
    src.components.icons --> "src/components/settings/import-jobs" { Loader2 }
    "src/components/language-provider" --> "src/components/settings/import-jobs" { useLanguage }
    src.components.ui.button --> "src/components/settings/import-jobs" { Button }
    src.components.ui.input --> "src/components/settings/import-jobs" { Input }
    "src/lib/import/jobs-types.d" --> "src/components/settings/import-jobs" { ImportJobSummary }
    "src/app/(settings)/settings/import/utils" --> "src/components/settings/import-jobs" {
        fetchImportJobs,
        removeImportJob,
        resumeImportJob,
    }
    "src/components/settings/import-jobs-utils" --> "src/components/settings/import-jobs" {
        IMPORT_JOBS_POLL_MS,
        getImportJobPercent,
        isImportJobActive,
    }
    "src/lib/import/jobs-types.d" --> "src/app/(settings)/settings/import/utils" {
        ImportJobSummary,
    }
    src.lib.auth.client --> "src/app/(settings)/settings/import/utils" { authFetch }
    src.lib.folders.client --> "src/app/(settings)/settings/import/utils" {
        getMailboxFolders,
        invalidateFolderCache,
    }
    "src/app/(settings)/settings/import/types.d" --> "src/app/(settings)/settings/import/utils" {
        ImapFormState,
        ImportFolderSummary,
        ImportSourceItem,
        ImportSourceOption,
        ImportSourceSection,
    }
    "src/lib/import/jobs-types.d" --> "src/components/settings/import-jobs-utils" {
        ImportJobSummary,
    }
    src.lib.auth.client --> "src/components/settings/import-messages-utils" { getAuthHeaders }
    "src/components/settings/import-messages-types.d" --> "src/components/settings/import-messages-utils" {
        ImportMessagesResult,
        ImportProgressHandler,
    }
    "src/components/language-provider" --> "src/components/settings/takeout-data-import" {
        useLanguage,
    }
    src.components.ui.input --> "src/components/settings/takeout-data-import" { Input }
    src.components.ui.label --> "src/components/settings/takeout-data-import" { Label }
    "src/hooks/use-current-user" --> "src/components/settings/takeout-data-import" {
        useCurrentUser,
    }
    "src/lib/import/takeout-data-utils" --> "src/components/settings/takeout-data-import" {
        scanTakeoutData,
    }
    "src/lib/import/takeout-data-types.d" --> "src/components/settings/takeout-data-import" {
        TakeoutScan,
    }
    "src/lib/import/zip-utils" --> "src/components/settings/takeout-data-import" { isZipSupported }
    "src/components/settings/takeout-calendar-card" --> "src/components/settings/takeout-data-import" {
        TakeoutCalendarCard,
    }
    "src/components/settings/takeout-contacts-card" --> "src/components/settings/takeout-data-import" {
        TakeoutContactsCard,
    }
    "src/components/settings/takeout-drive-card" --> "src/components/settings/takeout-data-import" {
        TakeoutDriveCard,
    }
    "src/lib/contacts/google-csv" --> "src/lib/import/takeout-data-utils" {
        decodeContactsCsv,
        isGoogleContactsHeader,
        parseCsv,
    }
    "src/lib/drive/import-utils" --> "src/lib/import/takeout-data-utils" { takeoutDrivePath }
    "src/lib/import/takeout-data-types.d" --> "src/lib/import/takeout-data-utils" {
        ContactSource,
        DriveRoot,
        TakeoutScan,
        TakeoutSource,
    }
    "src/lib/import/zip-types.d" --> "src/lib/import/takeout-data-utils" { ZipEntry }
    "src/lib/import/zip-utils" --> "src/lib/import/takeout-data-utils" {
        listZipEntries,
        openZipEntry,
        readStreamChunks,
        readZipEntryBytes,
    }
    src.lib.drive.utils --> "src/lib/drive/import-utils" {
        DRIVE_MAX_DEPTH,
        DRIVE_MAX_NAME_LENGTH,
        normalizeDriveName,
    }
    "src/lib/drive/import-types.d" --> "src/lib/drive/import-utils" {
        ImportFilePlan,
        ImportFileRequest,
        KnownDriveItem,
        TakeoutDrivePath,
    }
    src.components.icons --> "src/components/settings/takeout-calendar-card" { Upload }
    "src/components/language-provider" --> "src/components/settings/takeout-calendar-card" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/settings/takeout-calendar-card" { Button }
    src.components.ui.checkbox --> "src/components/settings/takeout-calendar-card" { Checkbox }
    src.components.ui.input --> "src/components/settings/takeout-calendar-card" { Input }
    src.lib.auth.client --> "src/components/settings/takeout-calendar-card" { authFetch }
    src.lib.calendar.ics --> "src/components/settings/takeout-calendar-card" { isIcsAddress }
    src.lib.folders.colors --> "src/components/settings/takeout-calendar-card" {
        FOLDER_COLOR_OPTIONS,
        FOLDER_COLOR_VALUES,
    }
    "src/lib/folders/color-keys" --> "src/components/settings/takeout-calendar-card" {
        folderColorKeys,
    }
    "src/lib/import/takeout-calendar-utils" --> "src/components/settings/takeout-calendar-card" {
        importCalendarBytes,
        parseRetryAfter,
        previewCalendarBytes,
    }
    "src/lib/import/takeout-calendar-types.d" --> "src/components/settings/takeout-calendar-card" {
        CalendarPost,
        CalendarPostResult,
    }
    "src/lib/import/takeout-data-utils" --> "src/components/settings/takeout-calendar-card" {
        readTakeoutSource,
    }
    src.lib.time.utils --> "src/components/settings/takeout-calendar-card" { getUserTimeZone }
    "src/components/settings/takeout-calendar-card-utils" --> "src/components/settings/takeout-calendar-card" {
        radioTarget,
        resultTone,
    }
    "src/components/settings/takeout-calendar-card-types.d" --> "src/components/settings/takeout-calendar-card" {
        CalendarRowState,
        CalendarRunProgress,
        CalendarRunResult,
        TakeoutCalendarCardProps,
    }
    "src/components/settings/takeout-calendar-card-types.d" --> "src/components/settings/takeout-calendar-card-utils" {
        CalendarRunResult,
    }
    src.components.icons --> "src/components/settings/takeout-contacts-card" { Upload }
    "src/components/language-provider" --> "src/components/settings/takeout-contacts-card" {
        useLanguage,
    }
    "src/components/mailbox-provider" --> "src/components/settings/takeout-contacts-card" {
        useSelectedMailbox,
    }
    "src/components/contacts/contact-avatar-form-utils" --> "src/components/settings/takeout-contacts-card" {
        uploadContactAvatar,
    }
    src.components.ui.button --> "src/components/settings/takeout-contacts-card" { Button }
    src.components.ui.checkbox --> "src/components/settings/takeout-contacts-card" { Checkbox }
    "src/hooks/use-current-user" --> "src/components/settings/takeout-contacts-card" {
        useCurrentUser,
    }
    src.lib.auth.client --> "src/components/settings/takeout-contacts-card" { authFetch }
    "src/lib/import/takeout-contacts-utils" --> "src/components/settings/takeout-contacts-card" {
        ContactsFileError,
        importContactsBytes,
        parseRetryAfter,
        previewContactsBytes,
    }
    "src/lib/import/takeout-contacts-types.d" --> "src/components/settings/takeout-contacts-card" {
        ContactPost,
        ContactPostResult,
    }
    "src/lib/import/takeout-data-utils" --> "src/components/settings/takeout-contacts-card" {
        readTakeoutSource,
    }
    "src/components/settings/takeout-contacts-card-utils" --> "src/components/settings/takeout-contacts-card" {
        contactsTone,
        isAddressBookOwner,
    }
    "src/components/settings/takeout-contacts-card-types.d" --> "src/components/settings/takeout-contacts-card" {
        ContactRunProgress,
        ContactRunResult,
        TakeoutContactsCardProps,
    }
    "src/lib/contacts/details-utils" --> "src/lib/import/takeout-contacts-utils" {
        importedContactEmails,
    }
    "src/lib/contacts/google-csv" --> "src/lib/import/takeout-contacts-utils" {
        MAX_CSV_ROWS,
        decodeContactsCsv,
        googleCsvMapper,
        isGoogleContactsHeader,
        parseCsv,
    }
    src.lib.contacts.vcard --> "src/lib/import/takeout-contacts-utils" {
        MAX_VCARDS,
        decodeContactPhoto,
        parseVcard,
        splitVcards,
    }
    "src/lib/contacts/vcard-types.d" --> "src/lib/import/takeout-contacts-utils" { ContactPhoto }
    "src/lib/import/takeout-calendar-utils" --> "src/lib/import/takeout-contacts-utils" {
        parseRetryAfter,
        sleepFor,
    }
    "src/lib/i18n/types.d" --> "src/lib/import/takeout-contacts-utils" { TranslationKey }
    "src/lib/import/takeout-contacts-types.d" --> "src/lib/import/takeout-contacts-utils" {
        ContactPhotoUpload,
        ContactPost,
        ContactPostResult,
        ContactRunNotice,
        ContactRunOptions,
        ContactRunSettings,
        ContactRunSummary,
    }
    "src/components/settings/takeout-contacts-card-types.d" --> "src/components/settings/takeout-contacts-card-utils" {
        ContactRunResult,
    }
    "src/app/(drive)/drive-upload" --> "src/components/settings/takeout-drive-card" {
        uploadDriveSource,
    }
    src.components.icons --> "src/components/settings/takeout-drive-card" { Upload }
    "src/components/language-provider" --> "src/components/settings/takeout-drive-card" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/settings/takeout-drive-card" { Button }
    src.components.ui.label --> "src/components/settings/takeout-drive-card" { Label }
    src.components.ui.select --> "src/components/settings/takeout-drive-card" { Select }
    src.lib.auth.client --> "src/components/settings/takeout-drive-card" { authFetch }
    src.lib.drive.utils --> "src/components/settings/takeout-drive-card" { formatDriveSize }
    "src/lib/import/takeout-calendar-utils" --> "src/components/settings/takeout-drive-card" {
        parseRetryAfter,
    }
    "src/lib/import/takeout-drive-utils" --> "src/components/settings/takeout-drive-card" {
        MAX_CONSECUTIVE_FAILURES,
        importDriveFiles,
    }
    "src/lib/import/takeout-drive-types.d" --> "src/components/settings/takeout-drive-card" {
        DrivePostResult,
        DriveRunProgress,
        DriveRunSummary,
    }
    "src/components/settings/takeout-drive-card-utils" --> "src/components/settings/takeout-drive-card" {
        canStartDrive,
        defaultDriveRoot,
        driveTone,
        folderOptions,
        freeStorage,
        isLargeImport,
        newFolderName,
        topFolders,
    }
    "src/components/settings/takeout-drive-card-types.d" --> "src/components/settings/takeout-drive-card" {
        DriveStorage,
        TakeoutDriveCardProps,
    }
    "src/lib/drive/import-utils" --> "src/lib/import/takeout-drive-utils" {
        MAX_IMPORT_FOLDERS,
        NESTED_TOO_DEEPLY,
        contentTypeForName,
        folderPrefixes,
    }
    "src/app/(drive)/drive-upload" --> "src/lib/import/takeout-drive-utils" { DriveUploadSource }
    "src/lib/import/takeout-data-types.d" --> "src/lib/import/takeout-drive-utils" { DriveFile }
    "src/lib/import/takeout-drive-types.d" --> "src/lib/import/takeout-drive-utils" {
        DrivePostResult,
        DriveRunDeps,
        DriveRunSettings,
        DriveRunSummary,
    }
    "src/lib/import/zip-utils" --> "src/lib/import/takeout-drive-utils" {
        createZipPartReader,
        openZipEntry,
    }
    "src/lib/import/takeout-data-types.d" --> "src/components/settings/takeout-drive-card-utils" {
        DriveRoot,
    }
    "src/lib/import/takeout-drive-types.d" --> "src/components/settings/takeout-drive-card-utils" {
        DriveRunSummary,
    }
    src.components.icons --> "src/components/settings/takeout-import" { Upload }
    "src/components/language-provider" --> "src/components/settings/takeout-import" { useLanguage }
    "src/components/mailbox-provider" --> "src/components/settings/takeout-import" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/components/settings/takeout-import" { Button }
    src.components.ui.checkbox --> "src/components/settings/takeout-import" { Checkbox }
    src.components.ui.input --> "src/components/settings/takeout-import" { Input }
    src.components.ui.label --> "src/components/settings/takeout-import" { Label }
    "src/lib/i18n/types.d" --> "src/components/settings/takeout-import" { TranslationKey }
    "src/lib/import/gmail-takeout-types.d" --> "src/components/settings/takeout-import" {
        TakeoutImportSummary,
    }
    "src/lib/import/gmail-takeout-utils" --> "src/components/settings/takeout-import" {
        parseIgnoredLabels,
        runTakeoutImport,
        splitMbox,
    }
    "src/lib/import/zip-utils" --> "src/components/settings/takeout-import" {
        isZipSupported,
        readStreamChunks,
    }
    "src/components/settings/takeout-import-types.d" --> "src/components/settings/takeout-import" {
        TakeoutRunState,
    }
    "src/components/settings/takeout-import-utils" --> "src/components/settings/takeout-import" {
        addTakeoutSummaries,
        clearTakeoutProgress,
        createTakeoutFolderResolver,
        createTakeoutUploader,
        emptyTakeoutSummary,
        formatBytes,
        getTakeoutProgress,
        getTakeoutSources,
        saveTakeoutProgress,
    }
    src.lib.auth.client --> "src/components/settings/takeout-import-utils" { authFetch }
    src.lib.folders.client --> "src/components/settings/takeout-import-utils" {
        getMailboxFolders,
        invalidateFolderCache,
    }
    "src/lib/import/gmail-takeout-types.d" --> "src/components/settings/takeout-import-utils" {
        TakeoutBatchMessage,
        TakeoutImportSummary,
        TakeoutUploadResponse,
    }
    "src/lib/import/zip-utils" --> "src/components/settings/takeout-import-utils" {
        listZipEntries,
        openZipEntry,
    }
    "src/components/settings/takeout-import-types.d" --> "src/components/settings/takeout-import-utils" {
        TakeoutSource,
        TakeoutSourceList,
    }
    src.lib.i18n.server --> "src/app/(settings)/settings/inbox/page" { getServerTranslator }
    "src/components/settings/appearance-settings" --> "src/app/(settings)/settings/inbox/page" {
        AppearanceSettings,
    }
    "src/components/settings/inbox-threading-settings" --> "src/app/(settings)/settings/inbox/page" {
        InboxThreadingSettings,
    }
    "src/components/settings/remote-content-settings" --> "src/app/(settings)/settings/inbox/page" {
        RemoteContentSettings,
    }
    "src/components/settings/recipient-address-settings" --> "src/app/(settings)/settings/inbox/page" {
        RecipientAddressSettings,
    }
    "src/components/settings/compose-defaults-settings" --> "src/app/(settings)/settings/inbox/page" {
        ComposeDefaultsSettings,
    }
    "src/components/settings/inbox-reading-layout-settings" --> "src/app/(settings)/settings/inbox/page" {
        InboxReadingLayoutSettings,
    }
    "src/components/settings/inbox-shortcuts-settings" --> "src/app/(settings)/settings/inbox/page" {
        InboxShortcutsSettings,
    }
    "src/components/settings/mailbox-auto-reply-form" --> "src/app/(settings)/settings/inbox/page" {
        MailboxAutoReplyForm,
    }
    "src/components/settings/spam-filter-settings" --> "src/app/(settings)/settings/inbox/page" {
        SpamFilterSettings,
    }
    "src/components/settings/trash-retention-settings" --> "src/app/(settings)/settings/inbox/page" {
        TrashRetentionSettings,
    }
    "src/components/settings/promotions-settings" --> "src/app/(settings)/settings/inbox/page" {
        PromotionsSettings,
    }
    "src/components/settings/push-notification-settings" --> "src/app/(settings)/settings/inbox/page" {
        PushNotificationSettings,
    }
    "src/components/settings/browser-notification-settings" --> "src/app/(settings)/settings/inbox/page" {
        BrowserNotificationSettings,
    }
    "src/components/language-provider" --> "src/components/settings/appearance-settings" {
        useLanguage,
    }
    "src/lib/i18n/types.d" --> "src/components/settings/appearance-settings" { TranslationKey }
    src.components.ui.select --> "src/components/settings/appearance-settings" { Select }
    "src/components/theme-utils" --> "src/components/settings/appearance-settings" {
        THEME_CHANGED_EVENT,
        ThemePreference,
        isThemePreference,
        readThemePreference,
        saveThemePreference,
    }
    "src/components/language-provider" --> "src/components/settings/inbox-threading-settings" {
        useLanguage,
    }
    src.components.ui.switch --> "src/components/settings/inbox-threading-settings" { Switch }
    "src/components/messages/use-conversation-view" --> "src/components/settings/inbox-threading-settings" {
        useConversationView,
    }
    "src/components/messages/use-latest-messages-first" --> "src/components/settings/inbox-threading-settings" {
        useLatestMessagesFirst,
    }
    "src/components/language-provider" --> "src/components/settings/remote-content-settings" {
        useLanguage,
    }
    "src/components/messages/use-remote-content-utils" --> "src/components/settings/remote-content-settings" {
        RemoteContentMode,
        loadRemoteContentPolicy,
        updateRemoteContentMode,
    }
    "src/components/messages/use-show-full-recipient-addresses" --> "src/components/settings/recipient-address-settings" {
        useShowFullRecipientAddresses,
    }
    "src/components/language-provider" --> "src/components/settings/recipient-address-settings" {
        useLanguage,
    }
    src.components.ui.switch --> "src/components/settings/recipient-address-settings" { Switch }
    "src/components/compose/compose-preferences-utils" --> "src/components/settings/compose-defaults-settings" {
        loadComposePreferences,
        updateComposePreferences,
    }
    "src/components/language-provider" --> "src/components/settings/compose-defaults-settings" {
        useLanguage,
    }
    src.components.ui.select --> "src/components/settings/compose-defaults-settings" { Select }
    src.components.ui.switch --> "src/components/settings/compose-defaults-settings" { Switch }
    "src/lib/compose/compose-utils" --> "src/components/settings/compose-defaults-settings" {
        DEFAULT_UNDO_SEND_SECONDS,
        UNDO_SEND_OPTIONS,
        parseUndoSendSeconds,
    }
    "src/lib/compose/types.d" --> "src/components/settings/compose-defaults-settings" {
        ComposePreferences,
    }
    "src/components/language-provider" --> "src/components/settings/inbox-reading-layout-settings" {
        useLanguage,
    }
    src.components.ui.switch --> "src/components/settings/inbox-reading-layout-settings" { Switch }
    "src/components/messages/use-two-column-reading" --> "src/components/settings/inbox-reading-layout-settings" {
        useTwoColumnReading,
    }
    "src/components/messages/use-auto-advance" --> "src/components/settings/inbox-reading-layout-settings" {
        useAutoAdvanceEnabled,
    }
    "src/components/language-provider" --> "src/components/settings/inbox-shortcuts-settings" {
        useLanguage,
    }
    src.components.shortcuts.index --> "src/components/settings/inbox-shortcuts-settings" {
        useShortcuts,
    }
    src.components.ui.switch --> "src/components/settings/inbox-shortcuts-settings" { Switch }
    "src/components/language-provider" --> "src/components/settings/mailbox-auto-reply-form" {
        useLanguage,
    }
    "src/components/mailbox-provider" --> "src/components/settings/mailbox-auto-reply-form" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/components/settings/mailbox-auto-reply-form" { Button }
    src.components.ui.checkbox --> "src/components/settings/mailbox-auto-reply-form" { Checkbox }
    src.components.ui.input --> "src/components/settings/mailbox-auto-reply-form" { Input }
    src.components.ui.label --> "src/components/settings/mailbox-auto-reply-form" { Label }
    src.components.ui.textarea --> "src/components/settings/mailbox-auto-reply-form" { Textarea }
    "src/components/settings/types.d" --> "src/components/settings/mailbox-auto-reply-form" {
        MailboxAutoReplySettings,
    }
    src.components.settings.utils --> "src/components/settings/mailbox-auto-reply-form" {
        updateMailboxAutoReply,
    }
    src.components.ui.switch --> "src/components/settings/mailbox-auto-reply-form" { Switch }
    src.lib.auth.client --> "src/components/settings/spam-filter-settings" { authFetch }
    "src/components/language-provider" --> "src/components/settings/spam-filter-settings" {
        useLanguage,
    }
    src.components.ui.switch --> "src/components/settings/spam-filter-settings" { Switch }
    "src/components/language-provider" --> "src/components/settings/trash-retention-settings" {
        useLanguage,
    }
    src.lib.auth.client --> "src/components/settings/trash-retention-settings" { authFetch }
    "src/lib/email/trash-retention-utils" --> "src/components/settings/trash-retention-settings" {
        TRASH_RETENTION_OPTIONS,
        describeTrashRetention,
    }
    "src/app/api/settings/trash-retention/types.d" --> "src/components/settings/trash-retention-settings" {
        TrashRetentionSettingsResponse,
    }
    src.components.ui.select --> "src/components/settings/trash-retention-settings" { Select }
    "src/components/language-provider" --> "src/components/settings/promotions-settings" {
        useLanguage,
    }
    "src/components/mailbox-provider" --> "src/components/settings/promotions-settings" {
        MailboxOption,
        useSelectedMailbox,
    }
    src.components.messages.utils --> "src/components/settings/promotions-settings" {
        getMailboxAddress,
    }
    src.components.ui.button --> "src/components/settings/promotions-settings" { Button }
    src.components.ui.select --> "src/components/settings/promotions-settings" { Select }
    src.components.ui.skeleton --> "src/components/settings/promotions-settings" { Skeleton }
    src.lib.auth.client --> "src/components/settings/promotions-settings" { authFetch }
    "src/lib/messages/change-events" --> "src/components/settings/promotions-settings" {
        dispatchMessagesChanged,
    }
    "src/lib/promotions/ui-utils" --> "src/components/settings/promotions-settings" {
        BackfillState,
        PROMOTION_MODE_OPTIONS,
        PromotionModeValue,
        canManagePromotions,
        getBackfillNotice,
        getModeErrorKey,
    }
    "src/components/language-provider" --> "src/components/settings/push-notification-settings" {
        useLanguage,
    }
    src.components.ui.switch --> "src/components/settings/push-notification-settings" { Switch }
    src.lib.push.client --> "src/components/settings/push-notification-settings" {
        disablePushNotifications,
        enablePushNotifications,
        getPushState,
    }
    src.lib.auth.client --> src.lib.push.client { authFetch }
    "src/components/language-provider" --> "src/components/settings/browser-notification-settings" {
        useLanguage,
    }
    src.components.ui.switch --> "src/components/settings/browser-notification-settings" { Switch }
    "src/hooks/message-realtime-utils" --> "src/components/settings/browser-notification-settings" {
        areBrowserNotificationsEnabled,
        setBrowserNotificationsEnabled,
    }
    "src/hooks/message-realtime-types.d" --> "src/hooks/message-realtime-utils" { NewMessageEvent }
    "src/hooks/types.d" --> "src/hooks/message-realtime-utils" { MessageCountsDelta }
    src.lib.push.client --> "src/hooks/message-realtime-utils" { hasActivePushSubscription }
    "src/lib/email/sender-label" --> "src/hooks/message-realtime-utils" { formatSenderLabel }
    "src/components/settings/settings-nav" --> "src/app/(settings)/settings/layout" { SettingsNav }
    "src/components/language-provider" --> "src/components/settings/settings-nav" { useLanguage }
    "src/hooks/use-current-user" --> "src/components/settings/settings-nav" { useCurrentUser }
    src.lib.utils --> "src/components/settings/settings-nav" { cn }
    "src/components/section-nav-sheet" --> "src/components/settings/settings-nav" {
        SectionNavSheet,
    }
    "src/components/settings/settings-nav-utils" --> "src/components/settings/settings-nav" {
        isActiveSettingsPath,
        settingsNavSections,
    }
    "src/app/(admin)/mailboxes/[id]/page" --> "src/app/(settings)/settings/mailboxes/[id]/page" {
        default,
    }
    "src/app/(admin)/mailboxes/page" --> "src/app/(settings)/settings/mailboxes/page" { default }
    "src/components/page-heading" --> "src/app/(settings)/settings/rules/page" { PageHeading }
    "src/components/settings/inbox-rules" --> "src/app/(settings)/settings/rules/page" {
        InboxRules,
    }
    "src/components/settings/domain-routing/domain-routing" --> "src/app/(settings)/settings/rules/page" {
        DomainRouting,
    }
    "src/components/language-provider" --> "src/components/page-heading" { useLanguage }
    "src/lib/i18n/types.d" --> "src/components/page-heading" { TranslationKey }
    src.components.icons --> "src/components/settings/inbox-rules" {
        Folder,
        Forward,
        Plus,
        ShieldAlert,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/settings/inbox-rules" { useLanguage }
    "src/components/mailbox-provider" --> "src/components/settings/inbox-rules" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/components/settings/inbox-rules" { Button }
    src.components.ui.card --> "src/components/settings/inbox-rules" {
        Card,
        CardContent,
        CardHeader,
        CardTitle,
    }
    src.components.ui.dialog --> "src/components/settings/inbox-rules" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.checkbox --> "src/components/settings/inbox-rules" { Checkbox }
    src.components.ui.input --> "src/components/settings/inbox-rules" { Input }
    src.components.ui.label --> "src/components/settings/inbox-rules" { Label }
    "src/lib/http/client-error" --> "src/components/settings/inbox-rules" { ClientRequestError }
    "src/components/settings/security-status-store" --> "src/components/settings/inbox-rules" {
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/components/settings/inbox-rules" {
        StepUpDialog,
    }
    "src/lib/email/mail-type-rule" --> "src/components/settings/inbox-rules" {
        MAIL_TYPE_UNSAFE_ACTION,
    }
    "src/components/settings/domain-routing/routing-rule-select" --> "src/components/settings/inbox-rules" {
        RoutingRuleSelect,
    }
    "src/components/settings/inbox-rules-types.d" --> "src/components/settings/inbox-rules" {
        InboxRule,
        InboxRuleInput,
    }
    "src/components/settings/inbox-rules-utils" --> "src/components/settings/inbox-rules" {
        createInboxRule,
        deleteInboxRule,
        fetchInboxRules,
        fetchRuleFolders,
        getInboxRuleDestination,
        getRuleFieldLabel,
        getRuleOperatorLabel,
        updateInboxRule,
    }
    src.lib.i18n.utils --> "src/components/settings/inbox-rules-utils" {
        Translator,
        defaultTranslator,
    }
    src.lib.auth.client --> "src/components/settings/inbox-rules-utils" { authFetch }
    "src/lib/http/client-error" --> "src/components/settings/inbox-rules-utils" { requestError }
    src.lib.folders.client --> "src/components/settings/inbox-rules-utils" { getMailboxFolders }
    "src/lib/email/mail-type-rule" --> "src/components/settings/inbox-rules-utils" {
        ruleErrorMessage,
    }
    "src/components/settings/inbox-rules-types.d" --> "src/components/settings/inbox-rules-utils" {
        InboxRule,
        InboxRuleInput,
        InboxRulesResponse,
        RuleFoldersResponse,
    }
    src.lib.i18n.server --> "src/app/(settings)/settings/security/page" { getServerTranslator }
    "src/components/settings/password-settings" --> "src/app/(settings)/settings/security/page" {
        PasswordSettings,
    }
    "src/components/settings/passkey-settings" --> "src/app/(settings)/settings/security/page" {
        PasskeySettings,
    }
    "src/components/settings/two-step-settings" --> "src/app/(settings)/settings/security/page" {
        TwoStepSettings,
    }
    "src/components/settings/device-settings" --> "src/app/(settings)/settings/security/page" {
        DeviceSettings,
    }
    src.components.icons --> "src/components/settings/password-settings" { KeyRound }
    "src/components/language-provider" --> "src/components/settings/password-settings" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/settings/password-settings" { Button }
    src.components.ui.dialog --> "src/components/settings/password-settings" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/settings/password-settings" { Input }
    src.components.ui.label --> "src/components/settings/password-settings" { Label }
    src.components.settings.utils --> "src/components/settings/password-settings" { updatePassword }
    "src/lib/auth/error-messages" --> "src/components/settings/password-settings" { authErrorText }
    "src/lib/http/client-error" --> "src/components/settings/password-settings" {
        ClientRequestError,
    }
    "src/components/settings/passkey-settings-utils" --> "src/components/settings/password-settings" {
        removePassword,
        setPassword,
    }
    "src/components/settings/security-status-store" --> "src/components/settings/password-settings" {
        refreshSecurityStatus,
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/components/settings/password-settings" {
        StepUpDialog,
    }
    "src/components/settings/passkey-first-choice" --> "src/components/settings/password-settings" {
        PasskeyFirstChoice,
        PasskeyPolicyChoice,
    }
    src.components.icons --> "src/components/settings/passkey-first-choice" {
        AlertTriangle,
        Info,
        KeyRound,
        ShieldCheck,
    }
    "src/components/language-provider" --> "src/components/settings/passkey-first-choice" {
        useLanguage,
    }
    src.components.ui.dialog --> "src/components/settings/passkey-first-choice" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.icons --> "src/components/settings/passkey-settings" {
        AlertTriangle,
        CheckCircle2,
        KeyRound,
        Pencil,
        Plus,
        ShieldCheck,
        ShieldOff,
        Trash2,
    }
    "src/components/language-provider" --> "src/components/settings/passkey-settings" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/settings/passkey-settings" { Button }
    src.components.ui.dialog --> "src/components/settings/passkey-settings" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/settings/passkey-settings" { Input }
    src.components.ui.label --> "src/components/settings/passkey-settings" { Label }
    "src/components/settings/passkey-settings-types.d" --> "src/components/settings/passkey-settings" {
        PasskeySummary,
    }
    "src/components/settings/passkey-settings-utils" --> "src/components/settings/passkey-settings" {
        addPasskey,
        checkPasskey,
        passkeyProvider,
        removePasskey,
        removePassword,
        renamePasskey,
        setSecondFactorRequirement,
    }
    "src/components/settings/passkey-first-choice" --> "src/components/settings/passkey-settings" {
        PasskeyFirstChoice,
        PasskeyPolicyChoice,
    }
    src.components.settings.utils --> "src/components/settings/passkey-settings" { disableMfa }
    "src/components/settings/security-status-store" --> "src/components/settings/passkey-settings" {
        refreshSecurityStatus,
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/components/settings/passkey-settings" {
        StepUpDialog,
    }
    "src/lib/auth/error-messages" --> "src/components/settings/passkey-settings" { authErrorText }
    "src/lib/auth/webauthn/browser-errors" --> "src/components/settings/passkey-settings" {
        isPasskeyCancellation,
        isPasskeyUnsupported,
    }
    "src/lib/http/client-error" --> "src/components/settings/passkey-settings" {
        ClientRequestError,
    }
    "src/lib/auth/webauthn/step-up-types.d" --> "src/components/settings/passkey-settings" {
        StepUpAction,
    }
    src.components.icons --> "src/components/settings/two-step-settings" {
        Copy,
        KeyRound,
        Smartphone,
    }
    "src/components/language-provider" --> "src/components/settings/two-step-settings" {
        useLanguage,
    }
    src.components.ui.button --> "src/components/settings/two-step-settings" { Button }
    src.components.ui.dialog --> "src/components/settings/two-step-settings" {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle,
    }
    src.components.ui.input --> "src/components/settings/two-step-settings" { Input }
    src.components.ui.label --> "src/components/settings/two-step-settings" { Label }
    src.components.ui.switch --> "src/components/settings/two-step-settings" { Switch }
    src.components.settings.utils --> "src/components/settings/two-step-settings" {
        beginMfaEnrollment,
        confirmMfaEnrollment,
        disableMfa,
    }
    "src/lib/auth/error-messages" --> "src/components/settings/two-step-settings" { authErrorText }
    "src/lib/http/client-error" --> "src/components/settings/two-step-settings" {
        ClientRequestError,
    }
    "src/components/settings/passkey-settings-utils" --> "src/components/settings/two-step-settings" {
        generateRecoveryCodes,
        setSecondFactorRequirement,
    }
    "src/components/settings/security-status-store" --> "src/components/settings/two-step-settings" {
        refreshSecurityStatus,
        useSecurityStatus,
    }
    "src/components/settings/step-up-dialog" --> "src/components/settings/two-step-settings" {
        StepUpDialog,
    }
    "src/components/ui/confirm-dialog" --> "src/components/settings/device-settings" {
        confirmDestructive,
    }
    src.components.icons --> "src/components/settings/device-settings" { Bell, Smartphone }
    "src/components/language-provider" --> "src/components/settings/device-settings" { useLanguage }
    src.components.ui.button --> "src/components/settings/device-settings" { Button }
    src.lib.time.utils --> "src/components/settings/device-settings" { formatUserDate }
    "src/components/settings/device-settings-types.d" --> "src/components/settings/device-settings" {
        MobileDevice,
    }
    "src/components/settings/device-settings-utils" --> "src/components/settings/device-settings" {
        loadDevices,
        signOutDevice,
    }
    src.lib.auth.client --> "src/components/settings/device-settings-utils" { authFetch }
    "src/components/settings/device-settings-types.d" --> "src/components/settings/device-settings-utils" {
        MobileDevice,
    }
    src.db.index --> "src/app/api/accounts/[id]/avatar/route" { getDb }
    src.db.schema.index --> "src/app/api/accounts/[id]/avatar/route" { users }
    "src/lib/avatar-images" --> "src/app/api/accounts/[id]/avatar/route" {
        getAvatarImageResponse,
        getOptimizedAvatarFiles,
        storeAvatarImages,
    }
    src.app.api.profile.avatar.utils --> "src/app/api/accounts/[id]/avatar/route" { avatarKeyFor }
    "src/app/api/accounts/[id]/types.d" --> "src/app/api/accounts/[id]/avatar/route" {
        AccountRouteParams,
    }
    "src/app/api/accounts/[id]/avatar/utils" --> "src/app/api/accounts/[id]/avatar/route" {
        getManagedAccount,
    }
    src.app.api.accounts.utils --> "src/app/api/accounts/[id]/avatar/route" { requireTeamAdmin }
    "src/app/api/accounts/[id]/utils" --> "src/app/api/accounts/[id]/avatar/route" {
        selectAccountById,
    }
    src.db.index --> "src/app/api/accounts/[id]/avatar/utils" { getDb }
    src.app.api.accounts.utils --> "src/app/api/accounts/[id]/avatar/utils" { requireTeamAdmin }
    "src/app/api/accounts/[id]/utils" --> "src/app/api/accounts/[id]/avatar/utils" {
        selectAccountById,
    }
    src.db.index --> src.app.api.accounts.utils { getDb }
    src.db.schema.index --> src.app.api.accounts.utils { domains, mailboxes, users }
    src.lib.auth.admin --> src.app.api.accounts.utils { assertAdmin }
    src.lib.auth.cookies --> src.app.api.accounts.utils { requireUser }
    src.lib.licenses.service --> src.app.api.accounts.utils { getLicenseEntitlements }
    src.lib.cloudflare --> src.app.api.accounts.utils { getEnv }
    src.db.index --> "src/app/api/accounts/[id]/utils" { getDb }
    src.db.schema.index --> "src/app/api/accounts/[id]/utils" { mailboxes, users }
    src.lib.auth.password --> "src/app/api/accounts/[id]/utils" { hasPasswordHash, hashPassword }
    src.lib.auth.webauthn.grants --> "src/app/api/accounts/[id]/utils" { bumpSecurityVersion }
    src.db.index --> "src/app/api/accounts/[id]/mailboxes/route" { getDb }
    src.db.schema.index --> "src/app/api/accounts/[id]/mailboxes/route" { domains, mailboxes }
    src.lib.auth.admin --> "src/app/api/accounts/[id]/mailboxes/route" { canManageUserAccount }
    src.app.api.accounts.utils --> "src/app/api/accounts/[id]/mailboxes/route" { requireTeamAdmin }
    "src/app/api/accounts/[id]/utils" --> "src/app/api/accounts/[id]/mailboxes/route" {
        selectAccountById,
    }
    "src/app/api/accounts/[id]/types.d" --> "src/app/api/accounts/[id]/mailboxes/route" {
        AccountRouteParams,
    }
    src.db.index --> "src/app/api/accounts/[id]/recovery/route" { getDb }
    src.app.api.accounts.utils --> "src/app/api/accounts/[id]/recovery/route" { requireTeamAdmin }
    src.lib.auth.admin --> "src/app/api/accounts/[id]/recovery/route" {
        canManageUserAccount,
        isPrimaryAdmin,
    }
    "src/app/api/accounts/[id]/utils" --> "src/app/api/accounts/[id]/recovery/route" {
        selectAccountById,
    }
    src.lib.http.request --> "src/app/api/accounts/[id]/recovery/route" { readJsonBody }
    src.lib.auth.session --> "src/app/api/accounts/[id]/recovery/route" {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.authorize --> "src/app/api/accounts/[id]/recovery/route" {
        authorizeSecurityChange,
    }
    src.lib.auth.webauthn.grants --> "src/app/api/accounts/[id]/recovery/route" {
        bumpSecurityVersion,
        createEnrollmentGrant,
    }
    src.lib.auth.webauthn.config --> "src/app/api/accounts/[id]/recovery/route" { getPublicOrigin }
    src.lib.mailboxes.audit --> "src/app/api/accounts/[id]/recovery/route" { createAuditLog }
    "src/lib/http/auth-error" --> "src/app/api/accounts/[id]/recovery/route" { authError }
    "src/app/api/accounts/[id]/types.d" --> "src/app/api/accounts/[id]/recovery/route" {
        AccountRouteParams,
    }
    src.lib.http.errors --> src.lib.http.request { RequestBodyTooLargeError }
    src.lib.auth.password --> src.lib.auth.webauthn.authorize { verifyPassword }
    src.lib.auth.mfa --> src.lib.auth.webauthn.authorize { verifySecondFactor }
    src.lib.auth.webauthn.grants --> src.lib.auth.webauthn.authorize { consumeStepUpGrant }
    "src/lib/auth/webauthn/step-up-types.d" --> src.lib.auth.webauthn.authorize { StepUpAction }
    src.db.index --> src.lib.auth.mfa { getDb }
    src.db.schema.index --> src.lib.auth.mfa { mfaRecoveryCodes, users }
    src.lib.branding.service --> src.lib.auth.mfa { getBranding }
    "src/lib/auth/recovery-codes" --> src.lib.auth.mfa {
        consumeRecoveryCode,
        countUnusedRecoveryCodes,
        issueRecoveryCodes,
    }
    src.lib.auth.session --> src.lib.auth.mfa { deleteUserSessions }
    src.lib.auth.totp --> src.lib.auth.mfa { buildOtpauthUrl, generateTotpSecret, matchTotpStep }
    "src/lib/auth/mfa-types.d" --> src.lib.auth.mfa { MfaEnrollment, MfaStatus }
    src.db.index --> "src/lib/auth/recovery-codes" { getDb }
    src.db.schema.index --> "src/lib/auth/recovery-codes" { mfaRecoveryCodes }
    src.lib.ids --> "src/lib/auth/recovery-codes" { newId }
    src.lib.auth.session --> "src/lib/auth/recovery-codes" { hashSessionToken }
    src.lib.branding.service --> src.lib.auth.webauthn.config { getBranding }
    src.lib.auth.webauthn.errors --> src.lib.auth.webauthn.config { WebAuthnOriginError }
    "src/lib/auth/error-codes" --> src.lib.auth.webauthn.errors { AuthErrorCode }
    "src/lib/auth/error-codes" --> "src/lib/http/auth-error" { AUTH_ERROR_MESSAGES, AuthErrorCode }
    src.lib.accounts.deletion --> "src/app/api/accounts/[id]/restore/route" { restoreAccount }
    src.app.api.accounts.utils --> "src/app/api/accounts/[id]/restore/route" { requireTeamAdmin }
    "src/app/api/accounts/[id]/types.d" --> "src/app/api/accounts/[id]/restore/route" {
        AccountRouteParams,
    }
    src.lib.auth.origin --> "src/app/api/accounts/[id]/restore/route" {
        hasValidSessionMutationOrigin,
    }
    src.db.index --> "src/app/api/accounts/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/accounts/[id]/route" { users }
    src.lib.validators --> "src/app/api/accounts/[id]/route" { updateManagedAccountSchema }
    src.app.api.accounts.utils --> "src/app/api/accounts/[id]/route" { requireTeamAdmin }
    src.lib.licenses.seats --> "src/app/api/accounts/[id]/route" { getAccountSeatError }
    src.lib.licenses.service --> "src/app/api/accounts/[id]/route" { getLicenseEntitlements }
    src.lib.auth.admin --> "src/app/api/accounts/[id]/route" {
        canManageUserAccount,
        canManageUsers,
        isPrimaryAdmin,
    }
    "src/app/api/accounts/[id]/types.d" --> "src/app/api/accounts/[id]/route" { AccountRouteParams }
    "src/app/api/accounts/[id]/utils" --> "src/app/api/accounts/[id]/route" {
        AccountSecurityChangedError,
        PasskeyOnlyPasswordError,
        selectAccountById,
        updateAccountCredentials,
    }
    src.lib.auth.session --> "src/app/api/accounts/[id]/route" {
        deleteUserSessions,
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.password --> "src/app/api/accounts/[id]/route" { hasPasswordHash }
    src.lib.auth.webauthn.grants --> "src/app/api/accounts/[id]/route" {
        bumpSecurityVersion,
        consumeStepUpGrant,
    }
    src.lib.mailboxes.audit --> "src/app/api/accounts/[id]/route" { createAuditLog }
    "src/lib/http/auth-error" --> "src/app/api/accounts/[id]/route" { authError }
    src.lib.auth.origin --> "src/app/api/accounts/[id]/route" { hasValidSessionMutationOrigin }
    src.db.index --> "src/app/api/accounts/[id]/transfer-primary/route" { getDb }
    src.db.schema.index --> "src/app/api/accounts/[id]/transfer-primary/route" { users }
    "src/lib/api/admin-key-revocation" --> "src/app/api/accounts/[id]/transfer-primary/route" {
        adminApiKeyRevocations,
    }
    src.lib.auth.admin --> "src/app/api/accounts/[id]/transfer-primary/route" { isPrimaryAdmin }
    src.lib.auth.origin --> "src/app/api/accounts/[id]/transfer-primary/route" {
        hasValidSessionMutationOrigin,
    }
    src.app.api.accounts.utils --> "src/app/api/accounts/[id]/transfer-primary/route" {
        requireTeamAdmin,
    }
    "src/app/api/accounts/[id]/types.d" --> "src/app/api/accounts/[id]/transfer-primary/route" {
        AccountRouteParams,
    }
    "src/app/api/accounts/[id]/utils" --> "src/app/api/accounts/[id]/transfer-primary/route" {
        selectAccountById,
    }
    src.db.index --> "src/lib/api/admin-key-revocation" { AppDatabase }
    src.db.schema.index --> "src/lib/api/admin-key-revocation" { apiKeys }
    "src/lib/api-keys" --> "src/lib/api/admin-key-revocation" { parseScopes }
    src.lib.api.scopes --> "src/lib/api/admin-key-revocation" { ADMIN_API_KEY_SCOPES }
    "src/lib/database-errors" --> src.app.api.accounts.create { isUniqueConstraintError }
    src.db.index --> src.app.api.accounts.create { getDb }
    src.db.schema.index --> src.app.api.accounts.create {
        domains,
        mailboxAliases,
        mailboxes,
        users,
    }
    src.lib.auth.password --> src.app.api.accounts.create { hashPassword }
    src.lib.booking.username --> src.app.api.accounts.create { ensureBookingUsername }
    "src/lib/cloudflare-api" --> src.app.api.accounts.create { rollbackEmailRoutingRuleChanges }
    "src/lib/cloudflare-api.types.d" --> src.app.api.accounts.create { CfEmailRoutingRuleChange }
    "src/lib/email/recipient-address" --> src.app.api.accounts.create {
        normalizeRecipientLocalPart,
    }
    src.lib.ids --> src.app.api.accounts.create { newId }
    "src/lib/deliverability/report-address" --> src.app.api.accounts.create {
        isReportAddressReserved,
    }
    src.lib.licenses.seats --> src.app.api.accounts.create { getAccountSeatError }
    "src/lib/mailboxes/domain-addresses" --> src.app.api.accounts.create {
        ensureMailboxDomainRouting,
    }
    "src/app/api/accounts/types.d" --> src.app.api.accounts.create { CreateUserAccountInput }
    src.app.api.accounts.utils --> src.app.api.accounts.create {
        accountListItemFromUser,
        domainOwnerIdsForAdmin,
        getDomainForAdmin,
    }
    "src/lib/database-errors" --> src.lib.booking.username { isUniqueConstraintError }
    src.db.index --> src.lib.booking.username { getDb }
    src.db.schema.index --> src.lib.booking.username { users }
    src.lib.booking.utils --> src.lib.booking.username { bookingUsernameFromEmail }
    src.db.index --> src.app.api.accounts.route { getDb }
    src.lib.validators --> src.app.api.accounts.route { createUserAccountSchema }
    src.lib.auth.admin --> src.app.api.accounts.route { canManageUsers, isPrimaryAdmin }
    src.lib.licenses.service --> src.app.api.accounts.route { getLicenseEntitlements }
    src.lib.licenses.seats --> src.app.api.accounts.route { countUsedAccountSeats }
    src.lib.accounts.deletion --> src.app.api.accounts.route { deleteAccounts }
    src.app.api.accounts.create --> src.app.api.accounts.route { createAccountResponse }
    src.app.api.accounts.utils --> src.app.api.accounts.route {
        accountListItemFromUser,
        listAccountsForAdmin,
        requireTeamAdmin,
        withoutAccountContacts,
    }
    src.lib.auth.origin --> src.app.api.accounts.route { hasValidSessionMutationOrigin }
    src.db.index --> src.app.api.activity.route { getDb }
    src.db.schema.index --> src.app.api.activity.route { auditLogs, users }
    src.lib.auth.admin --> src.app.api.activity.route { assertPrimaryAdmin }
    src.lib.auth.cookies --> src.app.api.activity.route { requireUser }
    src.lib.cloudflare --> src.app.api.activity.route { getEnv }
    "src/lib/api/query-params" --> src.app.api.activity.route { parseLimit }
    src.app.api.admin.agent.models.utils --> src.app.api.admin.agent.models.route { POST }
    src.lib.cloudflare --> src.app.api.admin.agent.models.utils { getEnv }
    src.lib.api.auth --> src.app.api.admin.agent.models.utils { requireSessionUser }
    src.lib.auth.admin --> src.app.api.admin.agent.models.utils { isPrimaryAdmin }
    "src/lib/agent/provider-models" --> src.app.api.admin.agent.models.utils {
        listCloudflareAgentModels,
        listCompatibleAgentModels,
    }
    src.lib.auth.origin --> src.app.api.admin.agent.models.utils { hasValidSessionMutationOrigin }
    src.lib.auth.cookies --> src.lib.api.auth { getCurrentUser }
    "src/lib/api/key-auth" --> src.lib.api.auth { authenticateApiKeyValue, hasScope }
    "src/lib/api/key-auth-types.d" --> src.lib.api.auth { ApiAuthResult }
    "src/lib/agent/provider-types.d" --> "src/lib/agent/provider-models" {
        AgentModelOption,
        AgentModelRates,
        AgentProviderPreset,
    }
    src.lib.agent.provider --> "src/lib/agent/provider-models" {
        getAgentProviderConfig,
        resolveAgentBaseUrl,
    }
    src.app.api.admin.agent.utils --> src.app.api.admin.agent.route { GET, PUT }
    src.db.index --> src.app.api.admin.agent.utils { getDb }
    src.db.schema.index --> src.app.api.admin.agent.utils {
        agentJobs,
        agentSendApprovals,
        appSettings,
    }
    src.lib.cloudflare --> src.app.api.admin.agent.utils { getEnv }
    src.lib.api.auth --> src.app.api.admin.agent.utils { requireSessionUser }
    src.lib.auth.admin --> src.app.api.admin.agent.utils { isPrimaryAdmin }
    src.lib.agent.provider --> src.app.api.admin.agent.utils {
        getAgentEnabled,
        getAgentProviderConfig,
        getAgentProviderPublicConfig,
        resolveAgentBaseUrl,
    }
    "src/lib/agent/provider-constants" --> src.app.api.admin.agent.utils { AGENT_SETTINGS_ID }
    "src/lib/agent/model-ids" --> src.app.api.admin.agent.utils { parseAgentModelIds }
    src.lib.auth.origin --> src.app.api.admin.agent.utils { hasValidSessionMutationOrigin }
    "src/app/api/admin/ai-usage/utils" --> "src/app/api/admin/ai-usage/route" { GET }
    src.db.index --> "src/app/api/admin/ai-usage/utils" { getDb }
    src.db.schema.index --> "src/app/api/admin/ai-usage/utils" { aiUsage }
    src.lib.cloudflare --> "src/app/api/admin/ai-usage/utils" { getEnv }
    src.lib.api.auth --> "src/app/api/admin/ai-usage/utils" { requireSessionUser }
    src.lib.auth.admin --> "src/app/api/admin/ai-usage/utils" { isPrimaryAdmin }
    src.lib.time.utils --> "src/app/api/admin/ai-usage/utils" {
        getRequestTimeZone,
        recentZonedDays,
    }
    "src/app/api/admin/api-keys/utils" --> "src/app/api/admin/api-keys/route" { DELETE, GET, POST }
    src.lib.cloudflare --> "src/app/api/admin/api-keys/utils" { getEnv }
    src.db.index --> "src/app/api/admin/api-keys/utils" { getDb }
    src.db.schema.index --> "src/app/api/admin/api-keys/utils" { agentSendApprovals, apiKeys }
    src.lib.api.auth --> "src/app/api/admin/api-keys/utils" { requireSessionUser }
    src.lib.auth.admin --> "src/app/api/admin/api-keys/utils" { isPrimaryAdmin }
    "src/lib/api-keys" --> "src/app/api/admin/api-keys/utils" {
        generateApiKey,
        parseScopes,
        scopesToJson,
    }
    src.lib.api.scopes --> "src/app/api/admin/api-keys/utils" { ADMIN_API_KEY_SCOPES }
    src.lib.ids --> "src/app/api/admin/api-keys/utils" { newId }
    src.lib.auth.origin --> "src/app/api/admin/api-keys/utils" { hasValidSessionMutationOrigin }
    src.lib.cloudflare --> src.app.api.admin.aws.route { getEnv }
    src.lib.api.auth --> src.app.api.admin.aws.route { requireSessionUser }
    src.lib.auth.admin --> src.app.api.admin.aws.route { isPrimaryAdmin }
    src.lib.auth.origin --> src.app.api.admin.aws.route { hasValidSessionMutationOrigin }
    src.lib.aws.validate --> src.app.api.admin.aws.route {
        AWS_IAM_POLICY,
        AwsCredentialsError,
        validateAwsConfig,
    }
    src.lib.aws.config --> src.app.api.admin.aws.route {
        clearAwsConfig,
        getAwsConfig,
        getAwsConfigStatus,
        saveAwsConfig,
    }
    src.lib.aws.client --> src.lib.aws.validate { AwsError }
    src.lib.aws.config --> src.lib.aws.validate { SES_RECEIVING_REGIONS, isValidRegion }
    src.lib.aws.ses --> src.lib.aws.validate { describeActiveRuleSet, getSesAccount }
    src.lib.aws.s3 --> src.lib.aws.validate { listBuckets }
    src.lib.aws.sns --> src.lib.aws.validate { listTopics }
    src.lib.aws.sts --> src.lib.aws.validate { getCallerIdentity }
    "src/lib/aws/aws-types.d" --> src.lib.aws.validate { AwsCapabilityReport, AwsConfig }
    src.lib.aws.client --> src.lib.aws.s3 { AwsError, awsRequest }
    src.lib.aws.sigv4 --> src.lib.aws.s3 { sha256Hex }
    "src/lib/aws/aws-types.d" --> src.lib.aws.s3 { AwsConfig }
    src.lib.aws.client --> src.lib.aws.sns { awsQuery }
    src.lib.aws.xml --> src.lib.aws.sns { xmlBlocks, xmlTag }
    "src/lib/aws/aws-types.d" --> src.lib.aws.sns { AwsConfig }
    src.lib.aws.client --> src.lib.aws.sts { awsQuery }
    src.lib.aws.xml --> src.lib.aws.sts { xmlTag }
    "src/lib/aws/aws-types.d" --> src.lib.aws.sts { AwsConfig }
    src.app.api.admin.general.utils --> src.app.api.admin.general.route { GET, PUT }
    src.db.index --> src.app.api.admin.general.utils { getDb }
    src.db.schema.index --> src.app.api.admin.general.utils { appSettings }
    src.lib.cloudflare --> src.app.api.admin.general.utils { getEnv }
    src.lib.api.auth --> src.app.api.admin.general.utils { requireSessionUser }
    src.lib.auth.admin --> src.app.api.admin.general.utils { isPrimaryAdmin }
    src.lib.auth.origin --> src.app.api.admin.general.utils { hasValidSessionMutationOrigin }
    "src/lib/email/attachment-limits" --> src.app.api.admin.general.utils {
        clampOutboundAttachmentMb,
    }
    "src/lib/email/attachment-policy" --> src.app.api.admin.general.utils {
        getOutboundAttachmentCeilingMb,
        getOutboundAttachmentMaxMb,
    }
    src.lib.runtime --> src.app.api.admin.general.utils { isNodeRuntime }
    src.lib.drive.storage --> src.app.api.admin.general.utils { getDriveStorageLimit }
    src.lib.dav.settings --> src.app.api.admin.general.utils { clearDavEnabledCache, isDavEnabled }
    "src/lib/database-errors" --> src.app.api.admin.general.utils { isMissingColumnError }
    src.db.index --> src.lib.drive.storage { getDb }
    src.db.schema.index --> src.lib.drive.storage { appSettings, driveItems }
    src.lib.migrations.service --> src.app.api.admin.migrations.GET { getMigrationStatus }
    src.app.api.admin.migrations.utils --> src.app.api.admin.migrations.GET {
        authorizeMigrationRequest,
    }
    src.lib.auth.origin --> src.app.api.admin.migrations.utils { hasValidSessionMutationOrigin }
    src.app.api.admin.update.utils --> src.app.api.admin.migrations.utils { authorizeAdminRequest }
    src.lib.auth.admin --> src.app.api.admin.update.utils { assertPrimaryAdmin }
    src.lib.auth.cookies --> src.app.api.admin.update.utils { requireUser }
    src.lib.cloudflare --> src.app.api.admin.update.utils { getEnv }
    src.lib.runtime --> src.app.api.admin.update.utils { isNodeRuntime }
    "src/app/api/admin/update/types.d" --> src.app.api.admin.update.utils {
        GitHubCompareResponse,
        GitHubContentResponse,
        GitHubRepositoryResponse,
        GitHubWorkflowDispatchResponse,
        PackageMetadata,
        UpdateChannel,
        UpdateConfigurationItem,
        UpdateDispatchConfig,
        UpdateStatus,
    }
    src.lib.migrations.service --> src.app.api.admin.migrations.POST { applyPendingMigrations }
    src.app.api.admin.migrations.utils --> src.app.api.admin.migrations.POST {
        authorizeMigrationRequest,
    }
    src.app.api.admin.migrations.GET --> src.app.api.admin.migrations.route { GET }
    src.app.api.admin.migrations.POST --> src.app.api.admin.migrations.route { POST }
    src.db.index --> "src/app/api/admin/resend-key/route" { getDb }
    src.db.schema.index --> "src/app/api/admin/resend-key/route" { appSettings }
    src.lib.cloudflare --> "src/app/api/admin/resend-key/route" { getEnv }
    src.lib.api.auth --> "src/app/api/admin/resend-key/route" { requireSessionUser }
    src.lib.auth.admin --> "src/app/api/admin/resend-key/route" { isPrimaryAdmin }
    src.lib.auth.origin --> "src/app/api/admin/resend-key/route" { hasValidSessionMutationOrigin }
    "src/lib/email/outbound-provider" --> "src/app/api/admin/resend-key/route" {
        getResendKeyStatus,
    }
    "src/lib/email/resend-api" --> "src/app/api/admin/resend-key/route" {
        checkResendKey,
        resendClient,
    }
    src.lib.auth.admin --> "src/app/api/admin/search-index/route" { assertAdmin }
    src.lib.api.auth --> "src/app/api/admin/search-index/route" { requireSessionUser }
    src.lib.cloudflare --> "src/app/api/admin/search-index/route" { getEnv }
    "src/lib/search/index-admin" --> "src/app/api/admin/search-index/route" {
        getSearchIndexStatus,
        rebuildSearchIndex,
    }
    src.lib.auth.origin --> "src/app/api/admin/search-index/route" { hasValidSessionMutationOrigin }
    "src/app/api/admin/spam-filter/utils" --> "src/app/api/admin/spam-filter/route" { GET, PUT }
    src.lib.cloudflare --> "src/app/api/admin/spam-filter/utils" { getEnv }
    src.lib.api.auth --> "src/app/api/admin/spam-filter/utils" { requireSessionUser }
    src.lib.auth.admin --> "src/app/api/admin/spam-filter/utils" { isPrimaryAdmin }
    src.lib.auth.origin --> "src/app/api/admin/spam-filter/utils" { hasValidSessionMutationOrigin }
    src.lib.spam.settings --> "src/app/api/admin/spam-filter/utils" {
        MAX_SPAM_BRANDS,
        checkAbuseChKey,
        checkSpamhausKey,
        getSpamIntelligenceStatus,
        saveSpamIntelligenceSettings,
        spamBrandSchema,
    }
    "src/lib/update/auto-update" --> src.app.api.admin.update.GET { getAutoUpdateSettings }
    src.app.api.admin.update.utils --> src.app.api.admin.update.GET {
        authorizeAdminRequest,
        getUpdateStatus,
    }
    src.db.index --> "src/lib/update/auto-update" { getDb }
    src.db.schema.index --> "src/lib/update/auto-update" { appSettings }
    src.lib.migrations.service --> "src/lib/update/auto-update" {
        applyPendingMigrations,
        getMigrationStatus,
    }
    src.lib.runtime --> "src/lib/update/auto-update" { isNodeRuntime }
    "src/app/api/admin/update/types.d" --> "src/lib/update/auto-update" { UpdateChannel }
    src.app.api.admin.update.utils --> "src/lib/update/auto-update" {
        dispatchUpdateWorkflow,
        getUpdateStatus,
    }
    "src/lib/update/auto-update" --> src.app.api.admin.update.PATCH { saveAutoUpdateSettings }
    src.lib.auth.origin --> src.app.api.admin.update.PATCH { hasValidSessionMutationOrigin }
    src.app.api.admin.update.utils --> src.app.api.admin.update.PATCH { authorizeAdminRequest }
    src.app.api.admin.update.utils --> src.app.api.admin.update.POST {
        authorizeAdminRequest,
        dispatchUpdateWorkflow,
        getUpdateStatus,
    }
    src.lib.runtime --> src.app.api.admin.update.POST { isNodeRuntime }
    src.lib.auth.origin --> src.app.api.admin.update.POST { hasValidSessionMutationOrigin }
    src.app.api.admin.update.GET --> src.app.api.admin.update.route { GET }
    src.app.api.admin.update.POST --> src.app.api.admin.update.route { POST }
    src.app.api.admin.update.PATCH --> src.app.api.admin.update.route { PATCH }
    src.lib.cloudflare --> src.app.api.agent.actions.confirm.route { getEnv }
    src.lib.auth.cookies --> src.app.api.agent.actions.confirm.route { getCurrentUser }
    src.lib.auth.origin --> src.app.api.agent.actions.confirm.route {
        hasValidSessionMutationOrigin,
    }
    src.lib.agent.actions --> src.app.api.agent.actions.confirm.route { confirmAgentAction }
    src.db.index --> src.lib.agent.actions { getDb }
    src.db.schema.index --> src.lib.agent.actions { agentChatMessages, agentConversations }
    "src/lib/auth/types.d" --> src.lib.agent.actions { SessionUser }
    src.lib.agent.tools --> src.lib.agent.actions { runEmailTool }
    "src/lib/agent/types.d" --> src.lib.agent.actions { EmailToolName }
    src.lib.cloudflare --> "src/app/api/agent/approvals/[id]/confirm/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/agent/approvals/[id]/confirm/route" { getCurrentUser }
    src.lib.agent.approvals.utils --> "src/app/api/agent/approvals/[id]/confirm/route" {
        confirmAgentSend,
    }
    src.lib.auth.origin --> "src/app/api/agent/approvals/[id]/confirm/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.cloudflare --> "src/app/api/agent/approvals/[id]/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/agent/approvals/[id]/route" { getCurrentUser }
    src.lib.agent.approvals.utils --> "src/app/api/agent/approvals/[id]/route" {
        getAgentSendRequest,
    }
    src.lib.cloudflare --> src.app.api.agent.approvals.route { getEnv }
    src.lib.auth.cookies --> src.app.api.agent.approvals.route { getCurrentUser }
    src.lib.agent.approvals.utils --> src.app.api.agent.approvals.route { requestAgentSend }
    src.lib.auth.origin --> src.app.api.agent.approvals.route { hasValidSessionMutationOrigin }
    src.app.api.agent.availability.utils --> src.app.api.agent.availability.route { GET }
    src.lib.cloudflare --> src.app.api.agent.availability.utils { getEnv }
    src.lib.auth.cookies --> src.app.api.agent.availability.utils { getCurrentUser }
    src.lib.agent.provider --> src.app.api.agent.availability.utils { getAgentEnabled }
    src.db.index --> "src/app/api/agent/calendar-confirmation/route" { getDb }
    src.db.schema.index --> "src/app/api/agent/calendar-confirmation/route" { calendarEvents }
    src.lib.cloudflare --> "src/app/api/agent/calendar-confirmation/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/agent/calendar-confirmation/route" { getCurrentUser }
    src.lib.auth.origin --> "src/app/api/agent/calendar-confirmation/route" {
        hasValidSessionMutationOrigin,
    }
    "src/lib/calendar/api-auth" --> "src/app/api/agent/calendar-confirmation/route" {
        calendarAccessError,
    }
    src.lib.calendar.confirmation --> "src/app/api/agent/calendar-confirmation/route" {
        readCalendarConfirmation,
    }
    src.lib.calendar.tools --> "src/app/api/agent/calendar-confirmation/route" { runCalendarTool }
    src.lib.auth.cookies --> "src/lib/calendar/api-auth" { getCurrentUser }
    "src/lib/api/key-auth" --> "src/lib/calendar/api-auth" { authenticateApiRequest, hasScope }
    "src/lib/api/key-auth-types.d" --> "src/lib/calendar/api-auth" { ApiAuthResult }
    "src/lib/calendar/api-auth-types.d" --> "src/lib/calendar/api-auth" { CalendarAuthorization }
    "src/lib/security/server-secret" --> src.lib.calendar.confirmation { getServerSecret }
    "src/lib/calendar/tool-types.d" --> src.lib.calendar.confirmation { CalendarToolName }
    src.db.index --> src.lib.calendar.tools { getDb }
    src.db.schema.index --> src.lib.calendar.tools { calendarEventOverrides, calendarEvents }
    "src/lib/agent/schema-utils" --> src.lib.calendar.tools { toolEmailSchema }
    src.lib.ids --> src.lib.calendar.tools { newId }
    src.lib.time.utils --> src.lib.calendar.tools { normalizeTimeZone, zonedDateFields }
    src.lib.calendar.colors --> src.lib.calendar.tools { normalizeCalendarColor }
    "src/lib/calendar/invite-store" --> src.lib.calendar.tools { listEventOverrides }
    src.lib.calendar.chunks --> src.lib.calendar.tools { chunkIds }
    src.lib.calendar.recurrence --> src.lib.calendar.tools {
        DEFAULT_REPEAT_DAYS,
        normalizeCalendarRepeatDays,
        normalizeRepeatInterval,
        normalizeRepeatWeek,
        normalizeRepeatWeekday,
        parseCalendarOccurrenceId,
    }
    "src/lib/calendar/tool-occurrences" --> src.lib.calendar.tools { expandToolEvents }
    src.lib.calendar.confirmation --> src.lib.calendar.tools {
        CONFIRMED_CALENDAR_TOOLS,
        createCalendarConfirmation,
    }
    "src/lib/calendar/tool-types.d" --> src.lib.calendar.tools {
        CalendarToolContext,
        CalendarToolName,
    }
    src.lib.cloudflare --> src.app.api.agent.chat.route { getEnv }
    src.lib.auth.cookies --> src.app.api.agent.chat.route { getCurrentUser }
    src.lib.agent.chat --> src.app.api.agent.chat.route { createAgentChatStream }
    "src/lib/agent/rate-limit" --> src.app.api.agent.chat.route { allowAgentRequest }
    src.lib.http.request --> src.app.api.agent.chat.route { readJsonBody }
    src.lib.auth.origin --> src.app.api.agent.chat.route { hasValidSessionMutationOrigin }
    src.lib.agent.errors --> src.app.api.agent.chat.route { agentProviderErrorMessage }
    src.lib.time.utils --> src.app.api.agent.chat.route { getRequestTimeZone }
    "src/lib/email/draft-access" --> src.lib.agent.chat { isOthersDraft }
    src.db.index --> src.lib.agent.chat { getDb }
    src.db.schema.index --> src.lib.agent.chat {
        agentChatMessages,
        agentConversations,
        mailboxAgentSettings,
        messages,
    }
    src.lib.mailboxes.access --> src.lib.agent.chat { getMailboxAccessLevel }
    src.lib.ids --> src.lib.agent.chat { newId }
    src.lib.agent.model --> src.lib.agent.chat {
        agentCurrentEmailContext,
        agentSystemPrompt,
        getAgentModel,
    }
    src.lib.agent.errors --> src.lib.agent.chat { agentProviderErrorMessage }
    src.lib.agent.provider --> src.lib.agent.chat { getAgentEnabled }
    src.lib.ai.usage --> src.lib.agent.chat { recordAiUsage }
    src.lib.agent.tools --> src.lib.agent.chat {
        EMAIL_TOOL_NAMES,
        emailToolDescriptions,
        emailToolSchemas,
        runEmailTool,
    }
    "src/lib/agent/types.d" --> src.lib.agent.chat { AgentToolContext }
    src.lib.time.utils --> src.lib.agent.chat { normalizeTimeZone }
    src.lib.calendar.tools --> src.lib.agent.chat {
        CALENDAR_TOOL_NAMES,
        calendarToolDescriptions,
        calendarToolSchemas,
        runCalendarTool,
    }
    src.db.index --> "src/app/api/agent/conversations/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/agent/conversations/[id]/route" { agentConversations }
    src.lib.cloudflare --> "src/app/api/agent/conversations/[id]/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/agent/conversations/[id]/route" { getCurrentUser }
    src.lib.agent.chat --> "src/app/api/agent/conversations/[id]/route" { getAgentChatHistory }
    src.lib.auth.origin --> "src/app/api/agent/conversations/[id]/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.cloudflare --> src.app.api.agent.conversations.route { getEnv }
    src.lib.auth.cookies --> src.app.api.agent.conversations.route { getCurrentUser }
    src.lib.agent.chat --> src.app.api.agent.conversations.route { listAgentConversations }
    src.db.index --> "src/app/api/agent/jobs/[id]/retry/route" { getDb }
    src.db.schema.index --> "src/app/api/agent/jobs/[id]/retry/route" { agentJobs }
    src.lib.cloudflare --> "src/app/api/agent/jobs/[id]/retry/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/agent/jobs/[id]/retry/route" { getCurrentUser }
    src.lib.mailboxes.access --> "src/app/api/agent/jobs/[id]/retry/route" { getMailboxAccessLevel }
    src.lib.auth.origin --> "src/app/api/agent/jobs/[id]/retry/route" {
        hasValidSessionMutationOrigin,
    }
    src.db.index --> src.app.api.agent.jobs.route { getDb }
    src.db.schema.index --> src.app.api.agent.jobs.route { agentJobs }
    src.lib.cloudflare --> src.app.api.agent.jobs.route { getEnv }
    src.lib.auth.cookies --> src.app.api.agent.jobs.route { getCurrentUser }
    src.lib.mailboxes.access --> src.app.api.agent.jobs.route { getMailboxAccessLevel }
    src.db.index --> "src/app/api/agent/mcp-keys/route" { getDb }
    src.db.schema.index --> "src/app/api/agent/mcp-keys/route" {
        agentSendApprovals,
        apiKeys,
        mcpKeyMailboxes,
    }
    src.lib.cloudflare --> "src/app/api/agent/mcp-keys/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/agent/mcp-keys/route" { getCurrentUser }
    "src/lib/api-keys" --> "src/app/api/agent/mcp-keys/route" {
        generateApiKey,
        parseScopes,
        scopesToJson,
    }
    src.lib.api.scopes --> "src/app/api/agent/mcp-keys/route" { ADMIN_API_KEY_SCOPES }
    src.lib.mailboxes.access --> "src/app/api/agent/mcp-keys/route" { getMailboxAccessLevel }
    src.lib.ids --> "src/app/api/agent/mcp-keys/route" { newId }
    src.lib.auth.origin --> "src/app/api/agent/mcp-keys/route" { hasValidSessionMutationOrigin }
    src.db.index --> src.app.api.agent.settings.route { getDb }
    src.db.schema.index --> src.app.api.agent.settings.route {
        agentJobs,
        mailboxAgentSettings,
        users,
    }
    src.lib.cloudflare --> src.app.api.agent.settings.route { getEnv }
    src.lib.auth.cookies --> src.app.api.agent.settings.route { getCurrentUser }
    src.lib.mailboxes.access --> src.app.api.agent.settings.route {
        getMailboxAccessLevel,
        listMailboxSenders,
    }
    src.lib.agent.provider --> src.app.api.agent.settings.route { getAgentProviderPublicConfig }
    src.lib.auth.admin --> src.app.api.agent.settings.route { isPrimaryAdmin }
    src.lib.auth.origin --> src.app.api.agent.settings.route { hasValidSessionMutationOrigin }
    src.lib.cloudflare --> "src/app/api/api-keys/route" { getEnv }
    src.db.index --> "src/app/api/api-keys/route" { getDb }
    src.db.schema.index --> "src/app/api/api-keys/route" {
        agentSendApprovals,
        apiKeys,
        mcpKeyMailboxes,
    }
    src.lib.auth.cookies --> "src/app/api/api-keys/route" { requireUser }
    "src/lib/api-keys" --> "src/app/api/api-keys/route" {
        generateApiKey,
        generateAppPassword,
        parseScopes,
        scopesToJson,
    }
    src.lib.api.scopes --> "src/app/api/api-keys/route" { ADMIN_API_KEY_SCOPES, API_KEY_SCOPES }
    src.lib.ids --> "src/app/api/api-keys/route" { newId }
    src.lib.mailboxes.access --> "src/app/api/api-keys/route" { getMailboxAccessLevel }
    src.lib.auth.origin --> "src/app/api/api-keys/route" { hasValidSessionMutationOrigin }
    "src/lib/auth/app-password-utils" --> "src/app/api/api-keys/route" { isListedAsAppPassword }
    src.lib.auth.session --> "src/app/api/api-keys/route" { getSessionTokenFromRequestHeaders }
    src.lib.auth.webauthn.grants --> "src/app/api/api-keys/route" { consumeStepUpGrant }
    "src/lib/http/auth-error" --> "src/app/api/api-keys/route" { authError }
    src.db.index --> "src/app/api/app-passwords/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/app-passwords/[id]/route" { apiKeys }
    src.lib.api.auth --> "src/app/api/app-passwords/[id]/route" { requireSessionUser }
    src.lib.auth.activity --> "src/app/api/app-passwords/[id]/route" { recordAuthActivity }
    "src/lib/auth/app-password-utils" --> "src/app/api/app-passwords/[id]/route" {
        isListedAsAppPassword,
    }
    src.lib.auth.origin --> "src/app/api/app-passwords/[id]/route" { hasValidSessionMutationOrigin }
    src.lib.cloudflare --> "src/app/api/app-passwords/[id]/route" { getEnv }
    src.lib.mailboxes.audit --> src.lib.auth.activity { createAuditLog }
    "src/lib/auth/client-ip" --> src.lib.auth.activity { getClientIp }
    "src/lib/auth/activity-types.d" --> src.lib.auth.activity {
        AuthActivityAction,
        AuthActivityMetadata,
    }
    src.db.index --> "src/app/api/app-passwords/route" { getDb }
    src.db.schema.index --> "src/app/api/app-passwords/route" { apiKeys, mcpKeyMailboxes }
    "src/lib/api-keys" --> "src/app/api/app-passwords/route" {
        generateAppPassword,
        parseScopes,
        scopesToJson,
    }
    src.lib.api.auth --> "src/app/api/app-passwords/route" { requireSessionUser }
    src.lib.auth.activity --> "src/app/api/app-passwords/route" { recordAuthActivity }
    "src/lib/auth/app-passwords" --> "src/app/api/app-passwords/route" {
        availableAppPasswordProtocols,
    }
    "src/lib/auth/app-password-utils" --> "src/app/api/app-passwords/route" {
        isListedAsAppPassword,
    }
    src.lib.auth.origin --> "src/app/api/app-passwords/route" { hasValidSessionMutationOrigin }
    src.lib.auth.session --> "src/app/api/app-passwords/route" { getSessionTokenFromRequestHeaders }
    src.lib.auth.webauthn.grants --> "src/app/api/app-passwords/route" { consumeStepUpGrant }
    src.lib.cloudflare --> "src/app/api/app-passwords/route" { getEnv }
    "src/lib/http/auth-error" --> "src/app/api/app-passwords/route" { authError }
    src.lib.http.request --> "src/app/api/app-passwords/route" { readJsonBody }
    src.lib.ids --> "src/app/api/app-passwords/route" { newId }
    src.lib.mailboxes.access --> "src/app/api/app-passwords/route" { getMailboxAccessLevel }
    src.lib.validators --> "src/app/api/app-passwords/route" { appPasswordCreateSchema }
    src.lib.cloudflare --> "src/app/api/attachment-policy/route" { getEnv }
    src.lib.api.auth --> "src/app/api/attachment-policy/route" { requireSessionUser }
    "src/lib/email/attachment-policy" --> "src/app/api/attachment-policy/route" {
        CLOUD_ATTACHMENT_THRESHOLD_BYTES,
        getOutboundAttachmentMaxMb,
    }
    src.db.index --> "src/app/api/audit-logs/route" { getDb }
    src.db.schema.index --> "src/app/api/audit-logs/route" { auditLogs, domains, mailboxes, users }
    src.lib.auth.admin --> "src/app/api/audit-logs/route" { assertPrimaryAdmin }
    src.lib.auth.cookies --> "src/app/api/audit-logs/route" { requireUser }
    src.lib.cloudflare --> "src/app/api/audit-logs/route" { getEnv }
    "src/lib/api/query-params" --> "src/app/api/audit-logs/route" { parseLimit }
    src.lib.cloudflare --> "src/app/api/auth/accounts/[userId]/avatar/route" { getEnv }
    "src/lib/avatar-images" --> "src/app/api/auth/accounts/[userId]/avatar/route" {
        getAvatarImageResponse,
    }
    src.lib.auth.accounts --> "src/app/api/auth/accounts/[userId]/avatar/route" {
        ACCOUNTS_COOKIE,
        parseAccountTokens,
        resolveAccounts,
    }
    src.lib.auth.session --> "src/app/api/auth/accounts/[userId]/avatar/route" {
        getSessionTokenFromRequestHeaders,
    }
    src.db.index --> src.lib.auth.accounts { getDb }
    src.db.schema.index --> src.lib.auth.accounts { sessions, users }
    src.lib.auth.session --> src.lib.auth.accounts { SESSION_COOKIE, hashSessionToken }
    src.lib.cloudflare --> src.app.api.auth.accounts.route { getEnv }
    src.lib.auth.origin --> src.app.api.auth.accounts.route { isSameOriginRequest }
    src.lib.auth.accounts --> src.app.api.auth.accounts.route {
        ACCOUNTS_COOKIE,
        cookieOptions,
        parseAccountTokens,
        resolveAccounts,
        serializeAccountTokens,
    }
    src.lib.auth.session --> src.app.api.auth.accounts.route {
        SESSION_COOKIE,
        deleteSession,
        getSessionTokenFromRequestHeaders,
    }
    src.lib.cloudflare --> src.app.api.auth.device.route { getEnv }
    src.db.index --> src.app.api.auth.device.route { getDb }
    src.db.schema.index --> src.app.api.auth.device.route { users }
    src.lib.auth.password --> src.app.api.auth.device.route { verifyPassword }
    src.lib.validators --> src.app.api.auth.device.route { deviceLoginSchema }
    "src/lib/auth/rate-limit" --> src.app.api.auth.device.route { allowDeviceLoginAttempt }
    src.lib.http.request --> src.app.api.auth.device.route { readJsonBody }
    src.lib.http.errors --> src.app.api.auth.device.route { RequestBodyTooLargeError }
    src.lib.auth.activity --> src.app.api.auth.device.route { recordAuthActivity }
    "src/lib/auth/login-challenge" --> src.app.api.auth.device.route {
        consumeLoginChallenge,
        createLoginChallenge,
        getLoginChallengeUserId,
    }
    src.lib.auth.mfa --> src.app.api.auth.device.route { verifySecondFactor }
    "src/lib/auth/second-factor-attempts" --> src.app.api.auth.device.route {
        clearSecondFactorAttempt,
        reserveSecondFactorAttempt,
    }
    "src/lib/auth/recovery-codes" --> src.app.api.auth.device.route { countUnusedRecoveryCodes }
    "src/lib/auth/device-keys" --> src.app.api.auth.device.route {
        createDeviceKey,
        revokeDeviceKey,
    }
    "src/lib/api/key-auth" --> src.app.api.auth.device.route { authenticateApiRequest }
    "src/lib/auth/client-ip" --> "src/lib/auth/rate-limit" { getClientIp }
    src.db.index --> "src/lib/auth/login-challenge" { getDb }
    src.db.schema.index --> "src/lib/auth/login-challenge" { loginChallenges }
    src.lib.ids --> "src/lib/auth/login-challenge" { newId }
    src.lib.auth.session --> "src/lib/auth/login-challenge" { hashSessionToken }
    src.db.index --> "src/lib/auth/second-factor-attempts" { getDb }
    src.db.schema.index --> "src/lib/auth/second-factor-attempts" { auditLogs }
    src.lib.ids --> "src/lib/auth/second-factor-attempts" { newId }
    src.lib.auth.activity --> "src/lib/auth/second-factor-attempts" { getAuthActivityMetadata }
    src.lib.cloudflare --> src.app.api.auth.login.route { getEnv }
    src.db.index --> src.app.api.auth.login.route { getDb }
    src.db.schema.index --> src.app.api.auth.login.route { users }
    src.lib.auth.password --> src.app.api.auth.login.route { verifyPassword }
    src.lib.validators --> src.app.api.auth.login.route { loginSchema }
    "src/lib/auth/rate-limit" --> src.app.api.auth.login.route { allowLoginAttempt }
    src.lib.auth.turnstile --> src.app.api.auth.login.route { verifyTurnstileToken }
    src.lib.http.request --> src.app.api.auth.login.route { readJsonBody }
    src.lib.http.errors --> src.app.api.auth.login.route { RequestBodyTooLargeError }
    "src/lib/auth/login-challenge" --> src.app.api.auth.login.route { createLoginChallenge }
    "src/lib/auth/login-response" --> src.app.api.auth.login.route { completeLogin }
    src.lib.auth.webauthn.credentials --> src.app.api.auth.login.route { countPasskeys }
    "src/lib/auth/recovery-codes" --> src.app.api.auth.login.route { countUnusedRecoveryCodes }
    "src/lib/http/auth-error" --> src.app.api.auth.login.route { authError }
    src.lib.ids --> src.lib.auth.turnstile { newId }
    "src/lib/auth/client-ip" --> src.lib.auth.turnstile { getClientIp }
    src.lib.auth.accounts --> "src/lib/auth/login-response" { ACCOUNTS_COOKIE, rememberLogin }
    src.lib.auth.session --> "src/lib/auth/login-response" { SESSION_COOKIE, createSession }
    src.lib.auth.activity --> "src/lib/auth/login-response" { recordAuthActivity }
    "src/lib/auth/activity-types.d" --> "src/lib/auth/login-response" { AuthActivityAction }
    src.db.index --> src.lib.auth.webauthn.credentials { getDb }
    src.db.schema.index --> src.lib.auth.webauthn.credentials { passkeyCredentials }
    src.lib.ids --> src.lib.auth.webauthn.credentials { newId }
    src.lib.auth.session --> src.lib.auth.webauthn.credentials { hashSessionToken }
    src.lib.cloudflare --> src.app.api.auth.logout.route { getEnv }
    src.lib.auth.session --> src.app.api.auth.logout.route {
        SESSION_COOKIE,
        deleteSession,
        getUserFromSession,
    }
    src.lib.auth.accounts --> src.app.api.auth.logout.route {
        ACCOUNTS_COOKIE,
        cookieOptions,
        parseAccountTokens,
        resolveAccounts,
        serializeAccountTokens,
    }
    src.lib.auth.activity --> src.app.api.auth.logout.route { recordAuthActivity }
    src.lib.auth.origin --> src.app.api.auth.logout.route { hasValidSessionMutationOrigin }
    src.lib.auth.cookies --> src.app.api.auth.me.route { getCurrentUser }
    src.lib.cloudflare --> src.app.api.auth.me.route { getEnv }
    src.lib.user --> src.app.api.auth.me.route { hasPrimaryDomain, userHasMailboxes }
    src.lib.licenses.service --> src.app.api.auth.me.route { getLicenseEntitlements }
    src.lib.runtime --> src.app.api.auth.me.route { hasCloudflareCredentials, isNodeRuntime }
    src.lib.cloudflare --> src.app.api.auth.mfa.verify.route { getEnv }
    src.db.index --> src.app.api.auth.mfa.verify.route { getDb }
    src.db.schema.index --> src.app.api.auth.mfa.verify.route { users }
    src.lib.validators --> src.app.api.auth.mfa.verify.route { mfaVerifySchema }
    "src/lib/auth/rate-limit" --> src.app.api.auth.mfa.verify.route { allowLoginAttempt }
    src.lib.http.request --> src.app.api.auth.mfa.verify.route { readJsonBody }
    src.lib.http.errors --> src.app.api.auth.mfa.verify.route { RequestBodyTooLargeError }
    src.lib.auth.activity --> src.app.api.auth.mfa.verify.route { recordAuthActivity }
    "src/lib/auth/login-challenge" --> src.app.api.auth.mfa.verify.route {
        consumeLoginChallenge,
        getLoginChallengeUserId,
    }
    src.lib.auth.mfa --> src.app.api.auth.mfa.verify.route { verifySecondFactor }
    "src/lib/auth/second-factor-attempts" --> src.app.api.auth.mfa.verify.route {
        clearSecondFactorAttempt,
        reserveSecondFactorAttempt,
    }
    "src/lib/auth/login-response" --> src.app.api.auth.mfa.verify.route { completeLogin }
    "src/lib/http/auth-error" --> src.app.api.auth.mfa.verify.route { authError }
    src.lib.cloudflare --> src.app.api.auth.passkey.mfa.options.route { getEnv }
    src.db.index --> src.app.api.auth.passkey.mfa.options.route { getDb }
    src.db.schema.index --> src.app.api.auth.passkey.mfa.options.route { users }
    "src/lib/auth/rate-limit" --> src.app.api.auth.passkey.mfa.options.route { allowLoginAttempt }
    src.lib.http.request --> src.app.api.auth.passkey.mfa.options.route { readJsonBody }
    src.lib.validators --> src.app.api.auth.passkey.mfa.options.route { passkeyMfaOptionsSchema }
    "src/lib/auth/login-challenge" --> src.app.api.auth.passkey.mfa.options.route {
        getLoginChallengeUserId,
    }
    src.lib.auth.webauthn.credentials --> src.app.api.auth.passkey.mfa.options.route {
        listPasskeys,
    }
    src.lib.auth.webauthn.service --> src.app.api.auth.passkey.mfa.options.route {
        createAuthenticationOptions,
    }
    src.lib.auth.webauthn.challenges --> src.app.api.auth.passkey.mfa.options.route {
        createCeremonyBinding,
        createWebAuthnChallenge,
        readCeremonyBindings,
        setCeremonyCookie,
    }
    "src/lib/http/auth-error" --> src.app.api.auth.passkey.mfa.options.route { authError }
    src.db.index --> src.lib.auth.webauthn.service { getDb }
    src.db.schema.index --> src.lib.auth.webauthn.service { users }
    src.lib.auth.webauthn.config --> src.lib.auth.webauthn.service { getWebAuthnConfig }
    src.lib.auth.webauthn.credentials --> src.lib.auth.webauthn.service {
        StoredPasskey,
        findPasskeyByCredentialId,
        recordPasskeyUse,
        savePasskey,
        toWebAuthnCredential,
    }
    src.lib.auth.webauthn.errors --> src.lib.auth.webauthn.service { PasskeyVerificationError }
    src.db.index --> src.lib.auth.webauthn.challenges { getDb }
    src.db.schema.index --> src.lib.auth.webauthn.challenges { webauthnChallenges }
    src.lib.ids --> src.lib.auth.webauthn.challenges { newId }
    src.lib.auth.session --> src.lib.auth.webauthn.challenges { hashSessionToken }
    src.lib.cloudflare --> src.app.api.auth.passkey.mfa.verify.route { getEnv }
    src.db.index --> src.app.api.auth.passkey.mfa.verify.route { getDb }
    src.db.schema.index --> src.app.api.auth.passkey.mfa.verify.route { users }
    "src/lib/auth/rate-limit" --> src.app.api.auth.passkey.mfa.verify.route { allowLoginAttempt }
    src.lib.http.request --> src.app.api.auth.passkey.mfa.verify.route { readJsonBody }
    src.lib.http.errors --> src.app.api.auth.passkey.mfa.verify.route { RequestBodyTooLargeError }
    src.lib.validators --> src.app.api.auth.passkey.mfa.verify.route { passkeyMfaVerifySchema }
    "src/lib/auth/login-challenge" --> src.app.api.auth.passkey.mfa.verify.route {
        consumeLoginChallenge,
        getLoginChallengeUserId,
    }
    src.lib.auth.webauthn.challenges --> src.app.api.auth.passkey.mfa.verify.route {
        consumeWebAuthnChallenge,
        readCeremonyBindings,
        removeCeremonyCookie,
    }
    src.lib.auth.webauthn.service --> src.app.api.auth.passkey.mfa.verify.route {
        isAuthenticationResponseJSON,
        verifyPasskeyAuthentication,
    }
    "src/lib/auth/login-response" --> src.app.api.auth.passkey.mfa.verify.route { completeLogin }
    src.lib.auth.activity --> src.app.api.auth.passkey.mfa.verify.route { recordAuthActivity }
    "src/lib/http/auth-error" --> src.app.api.auth.passkey.mfa.verify.route { authError }
    src.lib.auth.webauthn.errors --> src.app.api.auth.passkey.mfa.verify.route {
        PasskeyVerificationError,
    }
    src.lib.cloudflare --> src.app.api.auth.passkey.options.route { getEnv }
    "src/lib/auth/rate-limit" --> src.app.api.auth.passkey.options.route { allowLoginAttempt }
    src.lib.auth.webauthn.service --> src.app.api.auth.passkey.options.route {
        createAuthenticationOptions,
    }
    src.lib.auth.webauthn.challenges --> src.app.api.auth.passkey.options.route {
        createCeremonyBinding,
        createWebAuthnChallenge,
        readCeremonyBindings,
        setCeremonyCookie,
    }
    src.lib.auth.webauthn.errors --> src.app.api.auth.passkey.options.route {
        webAuthnUnavailableCode,
    }
    "src/lib/http/auth-error" --> src.app.api.auth.passkey.options.route { authError }
    src.lib.cloudflare --> src.app.api.auth.passkey.setup.context.route { getEnv }
    src.db.index --> src.app.api.auth.passkey.setup.context.route { getDb }
    src.db.schema.index --> src.app.api.auth.passkey.setup.context.route { users }
    src.lib.auth.webauthn.grants --> src.app.api.auth.passkey.setup.context.route {
        getEnrollmentGrant,
    }
    "src/lib/http/auth-error" --> src.app.api.auth.passkey.setup.context.route { authError }
    src.lib.cloudflare --> src.app.api.auth.passkey.setup.options.route { getEnv }
    src.db.index --> src.app.api.auth.passkey.setup.options.route { getDb }
    src.db.schema.index --> src.app.api.auth.passkey.setup.options.route { users }
    src.lib.http.request --> src.app.api.auth.passkey.setup.options.route { readJsonBody }
    src.lib.validators --> src.app.api.auth.passkey.setup.options.route {
        passkeySetupOptionsSchema,
    }
    src.lib.auth.webauthn.grants --> src.app.api.auth.passkey.setup.options.route {
        getEnrollmentGrant,
    }
    src.lib.auth.webauthn.credentials --> src.app.api.auth.passkey.setup.options.route {
        listPasskeys,
    }
    src.lib.auth.webauthn.service --> src.app.api.auth.passkey.setup.options.route {
        createRegistrationOptions,
    }
    src.lib.auth.webauthn.challenges --> src.app.api.auth.passkey.setup.options.route {
        createCeremonyBinding,
        createWebAuthnChallenge,
        readCeremonyBindings,
        setCeremonyCookie,
    }
    src.lib.auth.webauthn.errors --> src.app.api.auth.passkey.setup.options.route {
        webAuthnUnavailableCode,
    }
    "src/lib/http/auth-error" --> src.app.api.auth.passkey.setup.options.route { authError }
    src.lib.cloudflare --> src.app.api.auth.passkey.setup.verify.route { getEnv }
    src.db.index --> src.app.api.auth.passkey.setup.verify.route { getDb }
    src.db.schema.index --> src.app.api.auth.passkey.setup.verify.route {
        mfaRecoveryCodes,
        passkeyCredentials,
        users,
    }
    src.lib.http.request --> src.app.api.auth.passkey.setup.verify.route { readJsonBody }
    src.lib.http.errors --> src.app.api.auth.passkey.setup.verify.route { RequestBodyTooLargeError }
    src.lib.validators --> src.app.api.auth.passkey.setup.verify.route { passkeySetupSchema }
    src.lib.auth.webauthn.grants --> src.app.api.auth.passkey.setup.verify.route {
        SETUP_COOKIE,
        bumpSecurityVersion,
        consumeEnrollmentGrant,
        getEnrollmentGrant,
    }
    src.lib.auth.webauthn.credentials --> src.app.api.auth.passkey.setup.verify.route {
        buildPasskeyRow,
        deletePasskey,
    }
    src.lib.auth.webauthn.challenges --> src.app.api.auth.passkey.setup.verify.route {
        consumeWebAuthnChallenge,
        readCeremonyBindings,
        removeCeremonyCookie,
    }
    src.lib.auth.webauthn.service --> src.app.api.auth.passkey.setup.verify.route {
        isRegistrationResponseJSON,
        savePasskeyRegistration,
        verifyPasskeyRegistrationResponse,
    }
    src.lib.auth.password --> src.app.api.auth.passkey.setup.verify.route {
        PASSWORDLESS_PASSWORD_HASH,
    }
    src.lib.auth.session --> src.app.api.auth.passkey.setup.verify.route { deleteUserSessions }
    "src/lib/auth/login-response" --> src.app.api.auth.passkey.setup.verify.route { completeLogin }
    src.lib.auth.activity --> src.app.api.auth.passkey.setup.verify.route { recordAuthActivity }
    "src/lib/http/auth-error" --> src.app.api.auth.passkey.setup.verify.route { authError }
    src.lib.cloudflare --> src.app.api.auth.passkey.verify.route { getEnv }
    "src/lib/auth/rate-limit" --> src.app.api.auth.passkey.verify.route { allowLoginAttempt }
    src.lib.http.request --> src.app.api.auth.passkey.verify.route { readJsonBody }
    src.lib.http.errors --> src.app.api.auth.passkey.verify.route { RequestBodyTooLargeError }
    src.lib.validators --> src.app.api.auth.passkey.verify.route { passkeyCeremonySchema }
    src.lib.auth.webauthn.challenges --> src.app.api.auth.passkey.verify.route {
        consumeWebAuthnChallenge,
        readCeremonyBindings,
        removeCeremonyCookie,
    }
    src.lib.auth.webauthn.service --> src.app.api.auth.passkey.verify.route {
        isAuthenticationResponseJSON,
        verifyPasskeyAuthentication,
    }
    "src/lib/auth/login-response" --> src.app.api.auth.passkey.verify.route { completeLogin }
    src.lib.auth.activity --> src.app.api.auth.passkey.verify.route { recordAuthActivity }
    "src/lib/http/auth-error" --> src.app.api.auth.passkey.verify.route { authError }
    src.lib.auth.webauthn.errors --> src.app.api.auth.passkey.verify.route {
        PasskeyVerificationError,
    }
    src.lib.cloudflare --> "src/app/api/auth/password-reset/confirm/route" { getEnv }
    src.lib.validators --> "src/app/api/auth/password-reset/confirm/route" {
        passwordResetConfirmSchema,
    }
    "src/lib/auth/rate-limit" --> "src/app/api/auth/password-reset/confirm/route" {
        allowLoginAttempt,
    }
    src.lib.http.request --> "src/app/api/auth/password-reset/confirm/route" { readJsonBody }
    src.lib.http.errors --> "src/app/api/auth/password-reset/confirm/route" {
        RequestBodyTooLargeError,
    }
    "src/lib/auth/password-reset" --> "src/app/api/auth/password-reset/confirm/route" {
        completePasswordReset,
    }
    src.db.index --> "src/lib/auth/password-reset" { getDb }
    src.db.schema.index --> "src/lib/auth/password-reset" { passwordResetTokens, users }
    src.lib.ids --> "src/lib/auth/password-reset" { newId }
    src.lib.auth.password --> "src/lib/auth/password-reset" { hashPassword }
    src.lib.auth.session --> "src/lib/auth/password-reset" { deleteUserSessions, hashSessionToken }
    src.lib.branding.service --> "src/lib/auth/password-reset" { getBranding }
    "src/lib/email/system-mail" --> "src/lib/auth/password-reset" { sendSystemEmail }
    src.lib.mailboxes.audit --> "src/lib/auth/password-reset" { createAuditLog }
    "src/lib/auth/client-ip" --> "src/lib/auth/password-reset" { getClientIp }
    "src/lib/auth/password-reset-utils" --> "src/lib/auth/password-reset" {
        buildPasswordResetEmail,
    }
    src.lib.i18n.utils --> "src/lib/auth/password-reset" { Translator }
    src.lib.i18n.utils --> "src/lib/auth/password-reset-utils" { Translator }
    src.lib.cloudflare --> "src/app/api/auth/password-reset/request/route" { getEnv }
    src.lib.validators --> "src/app/api/auth/password-reset/request/route" {
        passwordResetRequestSchema,
    }
    "src/lib/auth/rate-limit" --> "src/app/api/auth/password-reset/request/route" {
        allowLoginAttempt,
    }
    src.lib.auth.turnstile --> "src/app/api/auth/password-reset/request/route" {
        verifyTurnstileToken,
    }
    src.lib.http.request --> "src/app/api/auth/password-reset/request/route" { readJsonBody }
    src.lib.http.errors --> "src/app/api/auth/password-reset/request/route" {
        RequestBodyTooLargeError,
    }
    "src/lib/auth/password-reset" --> "src/app/api/auth/password-reset/request/route" {
        requestPasswordReset,
    }
    "src/lib/auth/password-reset-utils" --> "src/app/api/auth/password-reset/request/route" {
        trustedResetOrigin,
    }
    src.lib.i18n.server --> "src/app/api/auth/password-reset/request/route" { getServerTranslator }
    src.lib.cloudflare --> src.app.api.auth.register.route { getEnv }
    src.db.index --> src.app.api.auth.register.route { getDb }
    src.db.schema.index --> src.app.api.auth.register.route { mailboxes, users }
    src.lib.auth.password --> src.app.api.auth.register.route {
        PASSWORDLESS_PASSWORD_HASH,
        hashPassword,
    }
    src.lib.auth.setup --> src.app.api.auth.register.route { hasAdminAccount }
    src.lib.auth.session --> src.app.api.auth.register.route { SESSION_COOKIE }
    src.lib.auth.webauthn.grants --> src.app.api.auth.register.route {
        SETUP_COOKIE,
        createEnrollmentGrant,
    }
    src.lib.ids --> src.app.api.auth.register.route { newId }
    src.lib.validators --> src.app.api.auth.register.route { firstRunRegisterSchema }
    src.lib.domains.service --> src.app.api.auth.register.route { addDomainForUser }
    src.lib.domains.rollback --> src.app.api.auth.register.route { rollbackDomainProvisioning }
    "src/lib/domains/types.d" --> src.app.api.auth.register.route { DomainProvisioningChanges }
    "src/lib/cloudflare-api" --> src.app.api.auth.register.route { ensureEmailRoutingRuleToWorker }
    "src/lib/mailboxes/domain-addresses" --> src.app.api.auth.register.route {
        ensureMailboxDomainRouting,
    }
    src.lib.http.request --> src.app.api.auth.register.route { readJsonBody }
    src.lib.http.errors --> src.app.api.auth.register.route { RequestBodyTooLargeError }
    src.lib.auth.turnstile --> src.app.api.auth.register.route { verifyTurnstileToken }
    src.lib.domains.errors --> src.app.api.auth.register.route { getDomainProvisioningError }
    src.lib.booking.username --> src.app.api.auth.register.route { ensureBookingUsername }
    src.db.index --> src.lib.domains.service { getDb }
    src.db.schema.index --> src.lib.domains.service { domains, mailboxes }
    "src/lib/mailboxes/domain-addresses" --> src.lib.domains.service { ensureMailboxDomainRouting }
    src.lib.ids --> src.lib.domains.service { newId }
    "src/lib/cloudflare-api" --> src.lib.domains.service {
        CfDnsRecord,
        EmailRoutingRuleCache,
        deleteSendingSubdomain,
        disableEmailRouting,
        getEmailRoutingDns,
        getEmailRoutingSettings,
        getSendingSubdomainDns,
        listSendingSubdomains,
    }
    "src/lib/domains/cloudflare-cleanup" --> src.lib.domains.service {
        deleteEmailRoutingRulesForDomain,
    }
    src.lib.domains.provision --> src.lib.domains.service {
        isManualZone,
        provisionDomainOnCloudflare,
    }
    "src/lib/domains/manual-dns" --> src.lib.domains.service { getManualDomainDns }
    src.lib.domains.rollback --> src.lib.domains.service { rollbackDomainProvisioning }
    "src/lib/domains/types.d" --> src.lib.domains.service { DomainProvisioningChanges }
    "src/lib/domains/sending-status" --> src.lib.domains.service { findSendingSubdomain }
    src.lib.domains.preflight --> src.lib.domains.service { preflightDomain }
    src.lib.domains.utils --> src.lib.domains.service { normalizeHostname }
    src.lib.runtime --> src.lib.domains.service { hasCloudflareCredentials }
    src.lib.mailboxes.audit --> src.lib.domains.service { createAuditLog }
    "src/lib/deliverability/mta-sts-guard" --> src.lib.domains.service {
        ForceCleanup,
        ForceDeleteConfirmError,
        assertDomainRemovable,
        assertMxChangeAllowed,
        forceCleanupMtaSts,
        republishMtaStsAfterMxChange,
    }
    "src/lib/cloudflare-api" --> "src/lib/domains/cloudflare-cleanup" {
        deleteEmailRoutingRule,
        listEmailRoutingRules,
    }
    "src/lib/cloudflare-api" --> src.lib.domains.provision {
        enableEmailRouting,
        findZoneByHostname,
        getEmailRoutingSettings,
    }
    "src/lib/domains/catch-all-routing" --> src.lib.domains.provision {
        ensureEmailRoutingCatchAllToWorker,
        getEmailRoutingCatchAll,
    }
    src.lib.domains.utils --> src.lib.domains.provision { isZoneApex, normalizeHostname }
    src.lib.runtime --> src.lib.domains.provision { hasCloudflareCredentials, isNodeRuntime }
    "src/lib/domains/types.d" --> src.lib.domains.provision {
        DomainProvisioningChanges,
        DomainProvisioningResult,
    }
    "src/lib/domains/mx-records" --> src.lib.domains.provision { removeMxRecords }
    src.lib.domains.rollback --> src.lib.domains.provision { rollbackDomainProvisioning }
    "src/lib/domains/sending-subdomain" --> src.lib.domains.provision { ensureSendingSubdomain }
    "src/lib/cloudflare-api" --> "src/lib/domains/catch-all-routing" { cfRequest }
    "src/lib/cloudflare-api.types.d" --> "src/lib/domains/catch-all-routing" { CfEmailRoutingRule }
    "src/lib/cloudflare-api-utils" --> "src/lib/domains/catch-all-routing" { getEmailWorkerName }
    "src/lib/cloudflare-dns" --> "src/lib/domains/mx-records" {
        createDnsRecord,
        deleteDnsRecord,
        listMxRecords,
    }
    "src/lib/cloudflare-api.types.d" --> "src/lib/domains/mx-records" { CfDnsRecord }
    "src/lib/cloudflare-dns.types.d" --> "src/lib/domains/mx-records" { CloudflareDnsRecordCreate }
    "src/lib/cloudflare-api" --> src.lib.domains.rollback {
        deleteEmailRoutingRuleForAddress,
        deleteSendingSubdomain,
        disableEmailRouting,
    }
    "src/lib/domains/catch-all-routing" --> src.lib.domains.rollback { restoreEmailRoutingCatchAll }
    "src/lib/domains/mx-records" --> src.lib.domains.rollback { restoreMxRecords }
    "src/lib/domains/types.d" --> src.lib.domains.rollback { DomainProvisioningChanges }
    "src/lib/cloudflare-api" --> "src/lib/domains/sending-subdomain" {
        createSendingSubdomain,
        listSendingSubdomains,
    }
    "src/lib/cloudflare-api-error" --> "src/lib/domains/sending-subdomain" {
        CloudflareApiError,
        isCloudflareApiErrorCode,
    }
    "src/lib/cloudflare-api.types.d" --> "src/lib/domains/sending-subdomain" {
        CfDnsRecord,
        CfSendingSubdomain,
    }
    "src/lib/domains/mx-records" --> "src/lib/domains/sending-subdomain" {
        listConflictingMxRecords,
        removeMxRecords,
    }
    "src/lib/domains/receiving-dns" --> "src/lib/domains/sending-subdomain" { MxConflictError }
    "src/lib/domains/sending-status" --> "src/lib/domains/sending-subdomain" {
        findSendingSubdomain,
    }
    "src/lib/dns-query" --> "src/lib/domains/receiving-dns" { queryDns }
    "src/lib/cloudflare-dns" --> "src/lib/domains/receiving-dns" {
        createDnsRecord,
        deleteDnsRecord,
        listMxRecords,
    }
    src.lib.domains.provision --> "src/lib/domains/receiving-dns" { isManualZone }
    "src/lib/cloudflare-api.types.d" --> "src/lib/domains/receiving-dns" { CfDnsRecord }
    "src/lib/domains/types.d" --> "src/lib/domains/receiving-dns" { DomainRow }
    "src/lib/cloudflare-api.types.d" --> "src/lib/domains/sending-status" { CfSendingSubdomain }
    src.lib.domains.service --> "src/lib/domains/manual-dns" { DomainDnsView }
    src.lib.domains.utils --> src.lib.domains.preflight { normalizeHostname }
    "src/lib/cloudflare-api" --> src.lib.domains.preflight { findZoneByHostname }
    src.lib.domains.provision --> src.lib.domains.preflight { MANUAL_ZONE_ID }
    "src/lib/domains/types.d" --> src.lib.domains.preflight { DomainPreflightResult }
    src.lib.runtime --> src.lib.domains.preflight { hasCloudflareCredentials }
    "src/lib/cloudflare-api-error" --> src.lib.domains.errors { isCloudflareApiErrorCode }
    "src/lib/domains/receiving-dns" --> src.lib.domains.errors { MxConflictError }
    "src/lib/domains/types.d" --> src.lib.domains.errors { DomainProvisioningError }
    src.lib.cloudflare --> "src/app/api/auth/step-up/options/route" { getEnv }
    src.lib.api.auth --> "src/app/api/auth/step-up/options/route" { requireSessionUser }
    "src/lib/auth/rate-limit" --> "src/app/api/auth/step-up/options/route" { allowLoginAttempt }
    src.lib.http.request --> "src/app/api/auth/step-up/options/route" { readJsonBody }
    src.lib.validators --> "src/app/api/auth/step-up/options/route" { passkeyStepUpOptionsSchema }
    src.lib.auth.webauthn.credentials --> "src/app/api/auth/step-up/options/route" { listPasskeys }
    src.lib.auth.webauthn.service --> "src/app/api/auth/step-up/options/route" {
        createAuthenticationOptions,
    }
    src.lib.auth.webauthn.challenges --> "src/app/api/auth/step-up/options/route" {
        createCeremonyBinding,
        createWebAuthnChallenge,
        readCeremonyBindings,
        setCeremonyCookie,
    }
    src.lib.auth.webauthn.errors --> "src/app/api/auth/step-up/options/route" {
        webAuthnUnavailableCode,
    }
    "src/lib/http/auth-error" --> "src/app/api/auth/step-up/options/route" { authError }
    src.lib.cloudflare --> "src/app/api/auth/step-up/route" { getEnv }
    src.lib.api.auth --> "src/app/api/auth/step-up/route" { requireSessionUser }
    src.lib.http.request --> "src/app/api/auth/step-up/route" { readJsonBody }
    src.lib.validators --> "src/app/api/auth/step-up/route" { passkeyStepUpSchema }
    src.lib.auth.password --> "src/app/api/auth/step-up/route" { verifyPassword }
    "src/lib/auth/rate-limit" --> "src/app/api/auth/step-up/route" { allowLoginAttempt }
    src.lib.auth.session --> "src/app/api/auth/step-up/route" { getSessionTokenFromRequestHeaders }
    src.lib.auth.webauthn.grants --> "src/app/api/auth/step-up/route" {
        StaleStepUpProofError,
        createStepUpGrant,
    }
    src.lib.auth.mfa --> "src/app/api/auth/step-up/route" { verifySecondFactor }
    "src/lib/http/auth-error" --> "src/app/api/auth/step-up/route" { authError }
    src.lib.cloudflare --> "src/app/api/auth/step-up/verify/route" { getEnv }
    src.lib.api.auth --> "src/app/api/auth/step-up/verify/route" { requireSessionUser }
    src.lib.http.request --> "src/app/api/auth/step-up/verify/route" { readJsonBody }
    src.lib.validators --> "src/app/api/auth/step-up/verify/route" { passkeyStepUpVerifySchema }
    "src/lib/auth/rate-limit" --> "src/app/api/auth/step-up/verify/route" { allowLoginAttempt }
    src.lib.auth.session --> "src/app/api/auth/step-up/verify/route" {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.challenges --> "src/app/api/auth/step-up/verify/route" {
        consumeWebAuthnChallenge,
        readCeremonyBindings,
        removeCeremonyCookie,
    }
    src.lib.auth.webauthn.service --> "src/app/api/auth/step-up/verify/route" {
        isAuthenticationResponseJSON,
        verifyPasskeyAuthentication,
    }
    src.lib.auth.webauthn.grants --> "src/app/api/auth/step-up/verify/route" {
        StaleStepUpProofError,
        createStepUpGrant,
    }
    "src/lib/http/auth-error" --> "src/app/api/auth/step-up/verify/route" { authError }
    src.lib.auth.webauthn.errors --> "src/app/api/auth/step-up/verify/route" {
        PasskeyVerificationError,
    }
    src.lib.cloudflare --> src.app.api.auth.switch.route { getEnv }
    src.lib.auth.origin --> src.app.api.auth.switch.route { isSameOriginRequest }
    src.lib.auth.accounts --> src.app.api.auth.switch.route {
        ACCOUNTS_COOKIE,
        cookieOptions,
        parseAccountTokens,
        resolveAccounts,
        serializeAccountTokens,
    }
    src.lib.auth.session --> src.app.api.auth.switch.route { SESSION_COOKIE }
    src.db.index --> "src/app/api/backups/[id]/download/route" { getDb }
    src.db.schema.index --> "src/app/api/backups/[id]/download/route" { backups }
    src.app.api.backups.admin --> "src/app/api/backups/[id]/download/route" { authorizeBackupAdmin }
    src.lib.auth.admin --> src.app.api.backups.admin { isPrimaryAdmin }
    src.lib.auth.cookies --> src.app.api.backups.admin { requireUser }
    src.lib.auth.unauthorized --> src.app.api.backups.admin { UnauthorizedError }
    src.lib.cloudflare --> src.app.api.backups.admin { getEnv }
    src.app.api.backups.admin --> "src/app/api/backups/[id]/route" { authorizeBackupAdmin }
    src.lib.backups.service --> "src/app/api/backups/[id]/route" { deleteBackup }
    src.lib.auth.origin --> "src/app/api/backups/[id]/route" { hasValidSessionMutationOrigin }
    src.lib.auth.admin --> src.app.api.backups.restore.route { assertPrimaryAdmin }
    src.lib.auth.cookies --> src.app.api.backups.restore.route { requireUser }
    src.lib.backups.export --> src.app.api.backups.restore.route { restoreDatabaseRecords }
    src.lib.cloudflare --> src.app.api.backups.restore.route { getEnv }
    src.lib.auth.origin --> src.app.api.backups.restore.route { hasValidSessionMutationOrigin }
    src.lib.backups.export --> src.app.api.backups.route { getBackupConfigurationStatus }
    src.lib.backups.runner --> src.app.api.backups.route { runDatabaseBackup }
    src.lib.backups.service --> src.app.api.backups.route {
        createBackupRecord,
        getBackupSettings,
        listBackups,
        updateBackupSettings,
    }
    src.app.api.backups.admin --> src.app.api.backups.route { authorizeBackupAdmin }
    src.app.api.backups.utils --> src.app.api.backups.route { parseBackupSettingsInput }
    src.lib.auth.origin --> src.app.api.backups.route { hasValidSessionMutationOrigin }
    "src/app/api/backups/types.d" --> src.app.api.backups.utils { BackupSettingsInput }
    "src/lib/backups/table-groups" --> src.app.api.backups.utils { BACKUP_TABLE_GROUPS }
    "src/lib/database-errors" --> "src/app/api/booking/[eventId]/route" { isUniqueConstraintError }
    src.db.index --> "src/app/api/booking/[eventId]/route" { getDb }
    src.db.schema.index --> "src/app/api/booking/[eventId]/route" { bookingEvents }
    src.lib.auth.cookies --> "src/app/api/booking/[eventId]/route" { getCurrentUser }
    src.lib.auth.origin --> "src/app/api/booking/[eventId]/route" { hasValidSessionMutationOrigin }
    src.lib.booking.utils --> "src/app/api/booking/[eventId]/route" { parseBookingEventInput }
    src.lib.cloudflare --> "src/app/api/booking/[eventId]/route" { getEnv }
    "src/lib/calendar/api-auth" --> "src/app/api/booking/[eventId]/route" { calendarAccessError }
    "src/app/api/booking/[eventId]/types.d" --> "src/app/api/booking/[eventId]/route" {
        BookingEventRouteContext,
    }
    src.lib.booking.hosts --> "src/app/api/booking/[eventId]/route" { validBookingHostIds }
    src.lib.licenses.service --> "src/app/api/booking/[eventId]/route" { getLicenseEntitlements }
    "src/lib/booking/confirmation-templates" --> "src/app/api/booking/[eventId]/route" {
        ConfirmationTemplatesUnavailableError,
        saveConfirmationTemplate,
        withConfirmationTemplates,
    }
    "src/lib/booking/confirmation-utils" --> "src/app/api/booking/[eventId]/route" {
        parseConfirmationTemplateInput,
    }
    src.db.index --> "src/lib/booking/confirmation-templates" { getDb }
    src.db.schema.index --> "src/lib/booking/confirmation-templates" {
        bookingConfirmationTemplates,
    }
    "src/lib/database-errors" --> "src/lib/booking/confirmation-templates" { isMissingTableError }
    "src/lib/booking/confirmation-utils" --> "src/lib/booking/confirmation-templates" {
        BookingConfirmationTemplate,
    }
    "src/lib/database-errors" --> src.app.api.booking.route { isUniqueConstraintError }
    src.db.index --> src.app.api.booking.route { getDb }
    src.db.schema.index --> src.app.api.booking.route { bookingEvents, users }
    src.lib.auth.cookies --> src.app.api.booking.route { getCurrentUser }
    src.lib.auth.origin --> src.app.api.booking.route { hasValidSessionMutationOrigin }
    src.lib.booking.utils --> src.app.api.booking.route { parseBookingEventInput }
    src.lib.cloudflare --> src.app.api.booking.route { getEnv }
    src.lib.ids --> src.app.api.booking.route { newId }
    src.lib.booking.username --> src.app.api.booking.route { ensureBookingUsername }
    src.lib.booking.hosts --> src.app.api.booking.route { validBookingHostIds }
    src.lib.licenses.service --> src.app.api.booking.route { getLicenseEntitlements }
    "src/lib/calendar/api-auth" --> src.app.api.booking.route { calendarAccessError }
    "src/lib/booking/confirmation-templates" --> src.app.api.booking.route {
        ConfirmationTemplatesUnavailableError,
        saveConfirmationTemplate,
        withConfirmationTemplates,
    }
    "src/lib/booking/confirmation-utils" --> src.app.api.booking.route {
        parseConfirmationTemplateInput,
    }
    "src/lib/database-errors" --> src.app.api.booking.settings.route { isUniqueConstraintError }
    src.db.index --> src.app.api.booking.settings.route { getDb }
    src.db.schema.index --> src.app.api.booking.settings.route { users }
    src.lib.auth.cookies --> src.app.api.booking.settings.route { getCurrentUser }
    src.lib.auth.origin --> src.app.api.booking.settings.route { hasValidSessionMutationOrigin }
    src.lib.booking.utils --> src.app.api.booking.settings.route { normalizeBookingUsername }
    src.lib.cloudflare --> src.app.api.booking.settings.route { getEnv }
    "src/lib/calendar/api-auth" --> src.app.api.booking.settings.route { calendarAccessError }
    "src/app/api/booking/settings/types.d" --> src.app.api.booking.settings.route {
        BookingSettingsInput,
    }
    src.db.index --> src.app.api.branding.icon.route { getDb }
    src.db.schema.index --> src.app.api.branding.icon.route { appSettings }
    src.lib.branding.service --> src.app.api.branding.icon.route { APP_SETTINGS_ID }
    src.lib.cloudflare --> src.app.api.branding.icon.route { getEnvAsync }
    src.lib.licenses.service --> src.app.api.branding.icon.route { getLicenseEntitlements }
    src.lib.auth.admin --> src.app.api.branding.route { assertPrimaryAdmin }
    src.lib.auth.cookies --> src.app.api.branding.route { requireUser }
    src.lib.branding.service --> src.app.api.branding.route { getBranding, updateBranding }
    src.lib.cloudflare --> src.app.api.branding.route { getEnv }
    src.app.api.branding.utils --> src.app.api.branding.route {
        BRANDING_ICON_TYPES,
        MAX_BRANDING_ICON_SIZE,
        isBrandingIcon,
    }
    "src/app/api/branding/types.d" --> src.app.api.branding.utils { UploadedBrandingIcon }
    src.db.index --> "src/app/api/calendar/events/[eventId]/route" { getDb }
    src.db.schema.index --> "src/app/api/calendar/events/[eventId]/route" {
        calendarEventOverrides,
        calendarEvents,
    }
    src.lib.cloudflare --> "src/app/api/calendar/events/[eventId]/route" { getEnv }
    src.lib.calendar.utils --> "src/app/api/calendar/events/[eventId]/route" {
        createCalendarInvitation,
    }
    src.lib.email.send --> "src/app/api/calendar/events/[eventId]/route" { sendEmail }
    "src/lib/calendar/invite-delivery" --> "src/app/api/calendar/events/[eventId]/route" {
        sendToAttendees,
    }
    "src/app/api/calendar/events/types.d" --> "src/app/api/calendar/events/[eventId]/route" {
        CalendarEventInput,
    }
    "src/app/api/calendar/events/[eventId]/types.d" --> "src/app/api/calendar/events/[eventId]/route" {
        CalendarEventRouteParams,
    }
    src.lib.calendar.colors --> "src/app/api/calendar/events/[eventId]/route" {
        normalizeCalendarColor,
    }
    "src/lib/calendar/reminder-utils" --> "src/app/api/calendar/events/[eventId]/route" {
        normalizeReminderMinutes,
    }
    src.lib.calendar.recurrence --> "src/app/api/calendar/events/[eventId]/route" {
        DEFAULT_REPEAT_DAYS,
        normalizeCalendarRepeat,
        normalizeCalendarRepeatDays,
        normalizeRepeatInterval,
        normalizeRepeatWeek,
        normalizeRepeatWeekday,
        parseCalendarOccurrenceId,
        parseCalendarRepeatDays,
        parseExcludedOccurrences,
    }
    src.lib.ids --> "src/app/api/calendar/events/[eventId]/route" { newId }
    src.lib.time.utils --> "src/app/api/calendar/events/[eventId]/route" {
        getRequestTimeZone,
        normalizeTimeZone,
    }
    "src/lib/calendar/api-auth" --> "src/app/api/calendar/events/[eventId]/route" {
        authorizeCalendarRequest,
        calendarKeyCanSendInvitations,
    }
    "src/lib/calendar/split-announcement" --> "src/app/api/calendar/events/[eventId]/route" {
        buildSplitAnnouncement,
    }
    src.lib.http.request --> "src/app/api/calendar/events/[eventId]/route" { readJsonObject }
    "src/lib/calendar/types.d" --> "src/lib/calendar/split-announcement" { CalendarRepeat }
    src.lib.calendar.utils --> "src/lib/calendar/split-announcement" { createCalendarInvitation }
    src.db.index --> src.app.api.calendar.events.route { getDb }
    src.db.schema.index --> src.app.api.calendar.events.route {
        calendarEventOverrides,
        calendarEvents,
        calendarOccurrenceResponses,
    }
    src.lib.cloudflare --> src.app.api.calendar.events.route { getEnv }
    src.lib.ids --> src.app.api.calendar.events.route { newId }
    src.lib.email.send --> src.app.api.calendar.events.route { sendEmail }
    "src/lib/calendar/invite-delivery" --> src.app.api.calendar.events.route { sendToAttendees }
    src.lib.deliverability.suppression --> src.app.api.calendar.events.route {
        assertInviteesAllowed,
    }
    "src/lib/deliverability/suppression-utils" --> src.app.api.calendar.events.route {
        SuppressedRecipientError,
        suppressedRecipientBody,
    }
    src.lib.calendar.utils --> src.app.api.calendar.events.route { createCalendarInvitation }
    src.lib.calendar.colors --> src.app.api.calendar.events.route { normalizeCalendarColor }
    "src/lib/calendar/reminder-utils" --> src.app.api.calendar.events.route {
        normalizeReminderMinutes,
    }
    src.lib.calendar.recurrence --> src.app.api.calendar.events.route {
        DEFAULT_REPEAT_DAYS,
        normalizeCalendarRepeat,
        normalizeCalendarRepeatDays,
        normalizeRepeatInterval,
        normalizeRepeatWeek,
        normalizeRepeatWeekday,
    }
    "src/app/api/calendar/events/types.d" --> src.app.api.calendar.events.route {
        CalendarEventInput,
    }
    src.lib.time.utils --> src.app.api.calendar.events.route {
        getRequestTimeZone,
        normalizeTimeZone,
    }
    src.lib.calendar.chunks --> src.app.api.calendar.events.route { chunkIds }
    "src/lib/calendar/api-auth" --> src.app.api.calendar.events.route {
        authorizeCalendarRequest,
        calendarKeyCanSendInvitations,
    }
    src.lib.http.request --> src.app.api.calendar.events.route { readJsonObject }
    src.db.index --> src.app.api.calendar.feed.route { getDb }
    src.db.schema.index --> src.app.api.calendar.feed.route {
        calendarEventOverrides,
        calendarEvents,
    }
    src.lib.cloudflare --> src.app.api.calendar.feed.route { getEnv }
    "src/lib/api/key-auth" --> src.app.api.calendar.feed.route { authenticateApiKeyValue }
    src.lib.calendar.feed --> src.app.api.calendar.feed.route {
        FeedOccurrenceOverride,
        buildCalendarFeed,
    }
    src.lib.calendar.chunks --> src.app.api.calendar.feed.route { chunkIds }
    src.lib.calendar.ics --> src.lib.calendar.feed {
        escapeIcsText,
        foldIcsLine,
        formatIcsUtc,
        joinIcsLines,
    }
    src.lib.calendar.recurrence --> src.lib.calendar.feed {
        parseCalendarRepeatDays,
        parseExcludedOccurrences,
    }
    src.db.index --> src.app.api.contacts.avatar.route { getDb }
    src.db.schema.index --> src.app.api.contacts.avatar.route { contacts }
    src.lib.auth.cookies --> src.app.api.contacts.avatar.route { requireUser }
    src.lib.cloudflare --> src.app.api.contacts.avatar.route { getEnv }
    "src/lib/avatar-images" --> src.app.api.contacts.avatar.route {
        deleteAvatarImages,
        getAvatarImageResponse,
        getOptimizedAvatarFiles,
        storeAvatarImages,
    }
    src.lib.contacts.utils --> src.app.api.contacts.avatar.route { getContactId }
    src.lib.email.address --> src.app.api.contacts.avatar.route { normalizeEmailAddress }
    src.lib.mailboxes.access --> src.app.api.contacts.avatar.route { getMailboxAccessLevel }
    src.app.api.profile.avatar.utils --> src.app.api.contacts.avatar.route { avatarKeyFor }
    src.lib.profile.sync --> src.app.api.contacts.avatar.route {
        getPersonalIdentityForAddress,
        syncPersonalIdentity,
    }
    src.app.api.contacts.avatar.utils --> src.app.api.contacts.avatar.route { contactAvatarKeyFor }
    src.app.api.contacts.utils --> src.app.api.contacts.avatar.route { addressesSeenInMailbox }
    src.lib.contacts.avatar --> src.app.api.contacts.avatar.utils { contactAvatarKeyFor }
    "src/lib/email/draft-access" --> src.app.api.contacts.utils { draftsVisibleTo }
    src.lib.email.address --> src.app.api.contacts.utils { addressListIncludes }
    src.db.index --> src.app.api.contacts.utils { getDb }
    src.db.schema.index --> src.app.api.contacts.utils { contactDetails, contacts, messages }
    src.db.sql --> src.app.api.contacts.utils { escapeLike, insensitiveLike }
    "src/lib/contacts/details-utils" --> src.app.api.contacts.utils { parseStoredDetails }
    "src/lib/contacts/details-types.d" --> src.app.api.contacts.utils { ContactDetailsData }
    src.lib.contacts.utils --> src.app.api.contacts.utils { getContactId }
    "src/lib/database-errors" --> src.app.api.contacts.utils { isMissingTableError }
    src.db.index --> src.app.api.contacts.block.route { getDb }
    src.lib.auth.cookies --> src.app.api.contacts.block.route { requireUser }
    src.lib.cloudflare --> src.app.api.contacts.block.route { getEnv }
    src.lib.contacts.service --> src.app.api.contacts.block.route {
        BlockDomainError,
        blockContact,
        blockSenderDomain,
    }
    src.lib.mailboxes.access --> src.app.api.contacts.block.route { getMailboxAccessLevel }
    "src/app/api/contacts/block/types.d" --> src.app.api.contacts.block.route {
        BlockContactRequest,
    }
    src.lib.http.request --> src.app.api.contacts.block.route { readJsonObject }
    src.db.index --> src.app.api.contacts.route { getDb }
    src.db.schema.index --> src.app.api.contacts.route { contacts }
    src.lib.auth.cookies --> src.app.api.contacts.route { requireUser }
    "src/lib/avatar-images" --> src.app.api.contacts.route { deleteAvatarImages }
    src.lib.cloudflare --> src.app.api.contacts.route { getEnv }
    src.lib.email.address --> src.app.api.contacts.route { normalizeEmailAddress }
    src.lib.contacts.gravatar --> src.app.api.contacts.route { importGravatarAvatar }
    src.lib.mailboxes.access --> src.app.api.contacts.route { getMailboxAccessLevel }
    src.lib.profile.sync --> src.app.api.contacts.route {
        getPersonalIdentityForAddress,
        syncPersonalIdentity,
    }
    src.lib.utils --> src.app.api.contacts.route { parseAddress }
    "src/app/api/contacts/types.d" --> src.app.api.contacts.route { ContactRequestInput }
    src.app.api.contacts.utils --> src.app.api.contacts.route {
        CONTACTS_LIST_MAX_LIMIT,
        addressesSeenInMailbox,
        getContactByEmail,
        getContactDetailsData,
        listContacts,
        parseContactsLimit,
        saveManualContact,
        toContactDetails,
    }
    src.lib.http.request --> src.app.api.contacts.route { readJsonObject }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/alerts/[alertId]/route" { getEnv }
    src.lib.deliverability.alerts --> "src/app/api/deliverability/[domainId]/alerts/[alertId]/route" {
        acknowledgeAlert,
    }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/alerts/[alertId]/route" {
        authorizeDomainAdmin,
    }
    "src/lib/deliverability/route-utils" --> "src/app/api/deliverability/[domainId]/alerts/[alertId]/route" {
        migrationRequired,
    }
    src.db.index --> src.lib.deliverability.alerts { getDb }
    src.db.schema.index --> src.lib.deliverability.alerts { deliverabilityAlerts }
    src.lib.api.auth --> src.lib.deliverability.access { requireSessionUser }
    src.lib.auth.admin --> src.lib.deliverability.access { canManageDomains }
    src.lib.auth.origin --> src.lib.deliverability.access { hasValidSessionMutationOrigin }
    src.lib.domains.utils --> src.lib.deliverability.access { domainListOwnerIds }
    src.lib.domains.service --> src.lib.deliverability.access { listUserDomains }
    "src/lib/database-errors" --> "src/lib/deliverability/route-utils" {
        isMissingColumnError,
        isMissingTableError,
    }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/dmarc/route" { getEnv }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/dmarc/route" {
        authorizeDomainAdmin,
    }
    "src/lib/deliverability/dmarc-stats" --> "src/app/api/deliverability/[domainId]/dmarc/route" {
        getDmarcStats,
        normalizeDays,
    }
    "src/lib/deliverability/route-utils" --> "src/app/api/deliverability/[domainId]/dmarc/route" {
        migrationRequired,
    }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/mta-sts/route" { getEnv }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/mta-sts/route" {
        authorizeDomainAdmin,
    }
    "src/lib/deliverability/mta-sts-admin" --> "src/app/api/deliverability/[domainId]/mta-sts/route" {
        getMtaStsState,
        mxDrift,
        updateMtaSts,
    }
    "src/lib/deliverability/route-utils" --> "src/app/api/deliverability/[domainId]/mta-sts/route" {
        migrationRequired,
    }
    "src/lib/dns-query" --> "src/app/api/deliverability/[domainId]/mta-sts/route" { queryDns }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/mta-sts/verified/route" { getEnv }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/mta-sts/verified/route" {
        authorizeDomainAdmin,
    }
    "src/lib/deliverability/mta-sts-admin" --> "src/app/api/deliverability/[domainId]/mta-sts/verified/route" {
        markMtaStsVerified,
    }
    "src/lib/deliverability/route-utils" --> "src/app/api/deliverability/[domainId]/mta-sts/verified/route" {
        migrationRequired,
    }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/reports/route" { getEnv }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/reports/route" {
        authorizeDomainAdmin,
    }
    "src/lib/deliverability/reports-admin" --> "src/app/api/deliverability/[domainId]/reports/route" {
        updateReports,
    }
    "src/lib/deliverability/route-utils" --> "src/app/api/deliverability/[domainId]/reports/route" {
        migrationRequired,
    }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/route" { getEnv }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/route" {
        authorizeDomainAdmin,
    }
    src.lib.deliverability.alerts --> "src/app/api/deliverability/[domainId]/route" {
        listOpenAlerts,
    }
    "src/lib/deliverability/dmarc-record" --> "src/app/api/deliverability/[domainId]/route" {
        hasRuaUri,
    }
    "src/lib/deliverability/reports-admin" --> "src/app/api/deliverability/[domainId]/route" {
        getReportState,
    }
    "src/lib/deliverability/route-utils" --> "src/app/api/deliverability/[domainId]/route" {
        migrationRequired,
    }
    "src/lib/dns-query" --> "src/app/api/deliverability/[domainId]/route" { queryDns }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/suppressions/[id]/route" {
        getEnv,
    }
    src.lib.mailboxes.audit --> "src/app/api/deliverability/[domainId]/suppressions/[id]/route" {
        createAuditLog,
    }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/suppressions/[id]/route" {
        authorizeDomainAdmin,
    }
    "src/lib/deliverability/suppression-admin" --> "src/app/api/deliverability/[domainId]/suppressions/[id]/route" {
        confirmSuppression,
        removeSuppression,
    }
    src.db.index --> "src/lib/deliverability/suppression-admin" { getDb }
    src.db.schema.index --> "src/lib/deliverability/suppression-admin" { emailSuppressions }
    src.db.sql --> "src/lib/deliverability/suppression-admin" { containsLike }
    "src/lib/deliverability/suppression-utils" --> "src/lib/deliverability/suppression-admin" {
        SuppressionReason,
        SuppressionSource,
    }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/suppressions/route" { getEnv }
    "src/lib/database-errors" --> "src/app/api/deliverability/[domainId]/suppressions/route" {
        isMissingTableError,
    }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/suppressions/route" {
        authorizeDomainAdmin,
    }
    "src/lib/deliverability/suppression-admin" --> "src/app/api/deliverability/[domainId]/suppressions/route" {
        listSuppressions,
    }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/tls-rpt/route" { getEnv }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/tls-rpt/route" {
        authorizeDomainAdmin,
    }
    "src/lib/deliverability/route-utils" --> "src/app/api/deliverability/[domainId]/tls-rpt/route" {
        migrationRequired,
    }
    "src/lib/deliverability/tls-rpt-admin" --> "src/app/api/deliverability/[domainId]/tls-rpt/route" {
        updateTlsRpt,
    }
    src.lib.cloudflare --> "src/app/api/deliverability/[domainId]/tls/route" { getEnv }
    src.lib.deliverability.access --> "src/app/api/deliverability/[domainId]/tls/route" {
        authorizeDomainAdmin,
    }
    "src/lib/deliverability/dmarc-record" --> "src/app/api/deliverability/[domainId]/tls/route" {
        hasRuaUri,
    }
    "src/lib/deliverability/dmarc-stats" --> "src/app/api/deliverability/[domainId]/tls/route" {
        normalizeDays,
    }
    "src/lib/deliverability/route-utils" --> "src/app/api/deliverability/[domainId]/tls/route" {
        migrationRequired,
    }
    "src/lib/deliverability/tls-rpt-admin" --> "src/app/api/deliverability/[domainId]/tls/route" {
        getTlsRptState,
    }
    "src/lib/deliverability/tls-stats" --> "src/app/api/deliverability/[domainId]/tls/route" {
        getTlsStats,
    }
    "src/lib/dns-query" --> "src/app/api/deliverability/[domainId]/tls/route" { queryDns }
    src.lib.cloudflare --> src.app.api.deliverability.feeds.resend.route { getEnv }
    src.lib.api.auth --> src.app.api.deliverability.feeds.resend.route { requireSessionUser }
    src.lib.auth.admin --> src.app.api.deliverability.feeds.resend.route { isPrimaryAdmin }
    src.lib.auth.origin --> src.app.api.deliverability.feeds.resend.route {
        hasValidSessionMutationOrigin,
    }
    "src/lib/database-errors" --> src.app.api.deliverability.feeds.resend.route {
        isMissingColumnError,
    }
    "src/lib/deliverability/resend-feed" --> src.app.api.deliverability.feeds.resend.route {
        removeResendFeed,
        setupResendFeed,
    }
    src.db.index --> "src/lib/deliverability/resend-feed" { getDb }
    src.db.schema.index --> "src/lib/deliverability/resend-feed" { appSettings }
    "src/lib/domains/resend-receiving" --> "src/lib/deliverability/resend-feed" { isPublicHttps }
    "src/lib/email/outbound-provider" --> "src/lib/deliverability/resend-feed" { getResendClient }
    "src/lib/email/resend-api" --> "src/lib/deliverability/resend-feed" {
        createResendWebhook,
        deleteResendWebhook,
        listResendWebhooks,
    }
    "src/lib/deliverability/provider-events" --> "src/lib/deliverability/resend-feed" {
        getResendEventsSecret,
    }
    src.db.index --> "src/lib/domains/resend-receiving" { getDb }
    src.db.schema.index --> "src/lib/domains/resend-receiving" { appSettings }
    src.lib.domains.provision --> "src/lib/domains/resend-receiving" { isManualZone }
    "src/lib/domains/receiving-dns" --> "src/lib/domains/resend-receiving" {
        hasMx,
        hasMxMatching,
        isResendInboundMx,
        publishMx,
        removeMx,
    }
    "src/lib/email/outbound-provider" --> "src/lib/domains/resend-receiving" {
        getResendClient,
        getResendKeyStatus,
    }
    "src/lib/email/resend-api" --> "src/lib/domains/resend-receiving" {
        ResendClient,
        ResendRestrictedKeyError,
        createResendDomain,
        createResendWebhook,
        deleteResendDomain,
        deleteResendWebhook,
        findResendDomain,
        getResendDomain,
        listResendWebhooks,
        resendClient,
        updateResendCapabilities,
        verifyResendDomain,
    }
    "src/lib/aws/ses-receiving-types.d" --> "src/lib/domains/resend-receiving" { ReceivingStep }
    "src/lib/domains/types.d" --> "src/lib/domains/resend-receiving" { DomainRow }
    "src/lib/domains/resend-receiving-types.d" --> "src/lib/domains/resend-receiving" {
        ResendReceivingView,
    }
    "src/lib/email/resend-api-types.d" --> "src/lib/domains/resend-receiving" { ResendDomainRecord }
    src.db.index --> "src/lib/deliverability/provider-events" { getDb }
    src.db.schema.index --> "src/lib/deliverability/provider-events" { appSettings }
    "src/lib/aws/ses-notification" --> "src/lib/deliverability/provider-events" {
        SnsEnvelope,
        safeEqual,
    }
    "src/lib/aws/sns-signature" --> "src/lib/deliverability/provider-events" { verifySnsSignature }
    src.lib.email.svix --> "src/lib/deliverability/provider-events" { verifySvixSignature }
    "src/lib/deliverability/ses-feed" --> "src/lib/deliverability/provider-events" {
        getSesFeedState,
    }
    src.lib.deliverability.suppression --> "src/lib/deliverability/provider-events" {
        getSuppressionMode,
        recordSuppressionEvents,
    }
    "src/lib/deliverability/suppression-utils" --> "src/lib/deliverability/provider-events" {
        mapResendEvent,
        mapSesNotification,
    }
    src.db.index --> "src/lib/deliverability/ses-feed" { getDb }
    src.db.schema.index --> "src/lib/deliverability/ses-feed" { appSettings, domains }
    src.lib.aws.config --> "src/lib/deliverability/ses-feed" { requireAwsConfig }
    src.lib.aws.ses --> "src/lib/deliverability/ses-feed" { setIdentityNotificationTopic }
    src.lib.aws.sns --> "src/lib/deliverability/ses-feed" {
        createTopic,
        listSubscriptions,
        setTopicPolicy,
        subscribeHttps,
    }
    src.lib.aws.sts --> "src/lib/deliverability/ses-feed" { getCallerIdentity }
    "src/lib/domains/resend-receiving" --> "src/lib/deliverability/ses-feed" { isPublicHttps }
    "src/lib/aws/aws-types.d" --> "src/lib/deliverability/ses-feed" { AwsConfig }
    src.lib.cloudflare --> src.app.api.deliverability.feeds.ses.route { getEnv }
    src.lib.api.auth --> src.app.api.deliverability.feeds.ses.route { requireSessionUser }
    src.lib.auth.admin --> src.app.api.deliverability.feeds.ses.route { isPrimaryAdmin }
    src.lib.auth.origin --> src.app.api.deliverability.feeds.ses.route {
        hasValidSessionMutationOrigin,
    }
    "src/lib/database-errors" --> src.app.api.deliverability.feeds.ses.route {
        isMissingColumnError,
    }
    "src/lib/deliverability/ses-feed" --> src.app.api.deliverability.feeds.ses.route {
        removeSesFeed,
        setupSesFeed,
    }
    src.lib.cloudflare --> src.app.api.deliverability.settings.route { getEnv }
    src.lib.api.auth --> src.app.api.deliverability.settings.route { requireSessionUser }
    src.lib.auth.admin --> src.app.api.deliverability.settings.route {
        canManageDomains,
        isPrimaryAdmin,
    }
    src.lib.auth.origin --> src.app.api.deliverability.settings.route {
        hasValidSessionMutationOrigin,
    }
    "src/lib/database-errors" --> src.app.api.deliverability.settings.route { isMissingColumnError }
    "src/lib/deliverability/provider-events" --> src.app.api.deliverability.settings.route {
        getResendEventsSecret,
    }
    "src/lib/deliverability/ses-feed" --> src.app.api.deliverability.settings.route {
        getSesFeedState,
    }
    src.lib.deliverability.suppression --> src.app.api.deliverability.settings.route {
        getSuppressionMode,
        setSuppressionMode,
    }
    src.lib.cloudflare --> "src/app/api/devices/[id]/route" { getEnv }
    src.lib.api.auth --> "src/app/api/devices/[id]/route" { requireSessionUser }
    src.lib.auth.origin --> "src/app/api/devices/[id]/route" { hasValidSessionMutationOrigin }
    "src/lib/auth/device-keys" --> "src/app/api/devices/[id]/route" { revokeDeviceKey }
    src.lib.cloudflare --> src.app.api.devices.route { getEnv }
    src.lib.api.auth --> src.app.api.devices.route { requireSessionUser }
    "src/lib/auth/device-keys" --> src.app.api.devices.route { listDeviceKeys }
    src.lib.cloudflare --> "src/app/api/domains/[id]/dns/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/domains/[id]/dns/route" { requireUser }
    src.lib.domains.service --> "src/app/api/domains/[id]/dns/route" { getDomainForUser }
    "src/lib/domains/dns-view" --> "src/app/api/domains/[id]/dns/route" { getDomainDnsView }
    "src/lib/dns-status" --> "src/lib/domains/dns-view" { DnsStatusSummary, summariseDns }
    "src/lib/domains/dns-audit" --> "src/lib/domains/dns-view" { DomainDnsAudit, auditDomainDns }
    src.lib.domains.service --> "src/lib/domains/dns-view" { DomainDnsView, getDomainDns }
    "src/lib/domains/types.d" --> "src/lib/domains/dns-view" { DomainRow }
    "src/lib/cloudflare-api" --> "src/lib/dns-status" { CfDnsRecord }
    "src/lib/domains/dns-audit" --> "src/lib/dns-status" {
        DnsAuthRecord,
        DnsAuthStatus,
        DomainDnsAudit,
    }
    "src/lib/cloudflare-api.types.d" --> "src/lib/domains/dns-audit" { CfDnsRecord }
    "src/lib/dns-query" --> "src/lib/domains/dns-audit" { DnsQueryType, queryDns }
    src.lib.cloudflare --> "src/app/api/domains/[id]/dns/setup/route" { getEnv }
    src.db.index --> "src/app/api/domains/[id]/dns/setup/route" { getDb }
    src.db.schema.index --> "src/app/api/domains/[id]/dns/setup/route" { domains }
    src.lib.auth.cookies --> "src/app/api/domains/[id]/dns/setup/route" { requireUser }
    src.lib.auth.admin --> "src/app/api/domains/[id]/dns/setup/route" { canManageDomains }
    src.lib.domains.service --> "src/app/api/domains/[id]/dns/setup/route" { getDomainForUser }
    "src/lib/domains/dns-view" --> "src/app/api/domains/[id]/dns/setup/route" { getDomainDnsView }
    "src/lib/domains/dns-audit" --> "src/app/api/domains/[id]/dns/setup/route" { DnsAuthRecord }
    "src/lib/domains/adopt-zone" --> "src/app/api/domains/[id]/dns/setup/route" {
        adoptCloudflareZone,
    }
    "src/lib/domains/dns-setup" --> "src/app/api/domains/[id]/dns/setup/route" {
        setupDomainDnsRecord,
    }
    "src/lib/domains/receiving-dns" --> "src/app/api/domains/[id]/dns/setup/route" {
        MxConflictError,
    }
    src.lib.auth.origin --> "src/app/api/domains/[id]/dns/setup/route" {
        hasValidSessionMutationOrigin,
    }
    "src/lib/deliverability/mta-sts-block-response" --> "src/app/api/domains/[id]/dns/setup/route" {
        mtaStsBlockedResponse,
    }
    src.db.index --> "src/lib/domains/adopt-zone" { getDb }
    src.db.schema.index --> "src/lib/domains/adopt-zone" { domains }
    src.lib.domains.provision --> "src/lib/domains/adopt-zone" { isManualZone }
    src.lib.domains.preflight --> "src/lib/domains/adopt-zone" { preflightDomain }
    "src/lib/domains/types.d" --> "src/lib/domains/adopt-zone" { DomainRow }
    src.lib.runtime --> "src/lib/domains/adopt-zone" { hasCloudflareCredentials }
    src.db.index --> "src/lib/domains/dns-setup" { getDb }
    src.db.schema.index --> "src/lib/domains/dns-setup" { domains }
    "src/lib/cloudflare-api" --> "src/lib/domains/dns-setup" { enableEmailRouting, getZone }
    "src/lib/cloudflare-dns" --> "src/lib/domains/dns-setup" { createDnsRecord, listDnsRecords }
    "src/lib/domains/catch-all-routing" --> "src/lib/domains/dns-setup" {
        ensureEmailRoutingCatchAllToWorker,
    }
    "src/lib/domains/dns-audit" --> "src/lib/domains/dns-setup" { DnsAuthRecord }
    src.lib.domains.provision --> "src/lib/domains/dns-setup" {
        isManualZone,
        shouldBindEmailCatchAllToWorker,
    }
    "src/lib/domains/mx-records" --> "src/lib/domains/dns-setup" { restoreMxRecordsAfterFailure }
    "src/lib/cloudflare-api.types.d" --> "src/lib/domains/dns-setup" { CfDnsRecord }
    "src/lib/domains/sending-subdomain" --> "src/lib/domains/dns-setup" { ensureSendingSubdomain }
    "src/lib/domains/types.d" --> "src/lib/domains/dns-setup" { DomainRow }
    src.lib.domains.utils --> "src/lib/domains/dns-setup" { isZoneApex }
    "src/lib/deliverability/mta-sts-guard" --> "src/lib/domains/dns-setup" {
        assertMxChangeAllowed,
        republishMtaStsAfterMxChange,
    }
    src.lib.i18n.server --> "src/lib/deliverability/mta-sts-block-response" { getServerTranslator }
    "src/lib/deliverability/mta-sts-guard" --> "src/lib/deliverability/mta-sts-block-response" {
        MtaStsBlockedError,
    }
    src.lib.cloudflare --> "src/app/api/domains/[id]/receiving/[provider]/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/domains/[id]/receiving/[provider]/route" { requireUser }
    src.lib.auth.admin --> "src/app/api/domains/[id]/receiving/[provider]/route" {
        canManageDomains,
    }
    src.lib.auth.origin --> "src/app/api/domains/[id]/receiving/[provider]/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.aws.config --> "src/app/api/domains/[id]/receiving/[provider]/route" { getAwsConfig }
    "src/lib/aws/ses-receiving" --> "src/app/api/domains/[id]/receiving/[provider]/route" {
        getSesReceivingView,
    }
    src.lib.domains.service --> "src/app/api/domains/[id]/receiving/[provider]/route" {
        getDomainForUser,
    }
    src.lib.domains.receiving --> "src/app/api/domains/[id]/receiving/[provider]/route" {
        setupReceiving,
    }
    "src/lib/domains/receiving-dns" --> "src/app/api/domains/[id]/receiving/[provider]/route" {
        MxConflictError,
    }
    "src/lib/domains/resend-receiving" --> "src/app/api/domains/[id]/receiving/[provider]/route" {
        getResendReceivingView,
    }
    "src/lib/deliverability/mta-sts-block-response" --> "src/app/api/domains/[id]/receiving/[provider]/route" {
        mtaStsBlockedResponse,
    }
    src.db.index --> "src/lib/aws/ses-receiving" { getDb }
    src.db.schema.index --> "src/lib/aws/ses-receiving" { appSettings }
    src.lib.aws.config --> "src/lib/aws/ses-receiving" { SES_RECEIVING_REGIONS, requireAwsConfig }
    src.lib.aws.client --> "src/lib/aws/ses-receiving" { AwsError }
    src.lib.aws.ses --> "src/lib/aws/ses-receiving" {
        activateRuleSet,
        createRuleSet,
        deleteReceiptRule,
        describeActiveRuleSet,
        describeReceiptRule,
        upsertReceiptRule,
    }
    src.lib.aws.s3 --> "src/lib/aws/ses-receiving" {
        bucketExists,
        createBucket,
        putBucketPolicy,
        putExpiryLifecycle,
    }
    src.lib.aws.sns --> "src/lib/aws/ses-receiving" {
        createTopic,
        listSubscriptions,
        setTopicPolicy,
        subscribeHttps,
    }
    src.lib.aws.sts --> "src/lib/aws/ses-receiving" { getCallerIdentity }
    "src/lib/domains/receiving-dns" --> "src/lib/aws/ses-receiving" {
        hasMx,
        isInboundSmtpMx,
        publishMx,
        removeMx,
    }
    src.lib.domains.provision --> "src/lib/aws/ses-receiving" { isManualZone }
    "src/lib/aws/aws-types.d" --> "src/lib/aws/ses-receiving" { SesReceivingState }
    "src/lib/aws/ses-receiving-types.d" --> "src/lib/aws/ses-receiving" {
        ReceivingStep,
        SesReceivingView,
    }
    "src/lib/domains/types.d" --> "src/lib/aws/ses-receiving" { DomainRow }
    src.db.index --> src.lib.domains.receiving { getDb }
    src.db.schema.index --> src.lib.domains.receiving { domains, mailboxes }
    "src/lib/cloudflare-api" --> src.lib.domains.receiving {
        EmailRoutingRuleCache,
        disableEmailRouting,
    }
    "src/lib/cloudflare-dns" --> src.lib.domains.receiving { deleteDnsRecord }
    "src/lib/domains/cloudflare-cleanup" --> src.lib.domains.receiving {
        deleteEmailRoutingRulesForDomain,
    }
    "src/lib/domains/mx-records" --> src.lib.domains.receiving {
        removeMxRecords,
        restoreMxRecordsAfterFailure,
    }
    "src/lib/domains/dns-setup" --> src.lib.domains.receiving { setupDomainDnsRecord }
    "src/lib/domains/adopt-zone" --> src.lib.domains.receiving { adoptCloudflareZone }
    src.lib.domains.provision --> src.lib.domains.receiving { isManualZone }
    "src/lib/domains/receiving-dns" --> src.lib.domains.receiving { MxConflictError, listDomainMx }
    "src/lib/domains/resend-receiving" --> src.lib.domains.receiving {
        hasResendReceivingConfig,
        removeResendReceiving,
        setupResendReceiving,
    }
    "src/lib/aws/ses-receiving" --> src.lib.domains.receiving {
        hasSesReceivingConfig,
        removeSesReceiving,
        setupSesReceiving,
    }
    "src/lib/mailboxes/domain-addresses" --> src.lib.domains.receiving {
        ensureMailboxDomainRouting,
    }
    "src/lib/deliverability/mta-sts-guard" --> src.lib.domains.receiving {
        assertMxChangeAllowed,
        republishMtaStsAfterMxChange,
    }
    "src/lib/cloudflare-api.types.d" --> src.lib.domains.receiving { CfDnsRecord }
    "src/lib/domains/types.d" --> src.lib.domains.receiving { DomainRow }
    src.db.index --> "src/app/api/domains/[id]/receiving/route" { getDb }
    src.db.schema.index --> "src/app/api/domains/[id]/receiving/route" { domains }
    src.lib.cloudflare --> "src/app/api/domains/[id]/receiving/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/domains/[id]/receiving/route" { requireUser }
    src.lib.auth.admin --> "src/app/api/domains/[id]/receiving/route" { canManageDomains }
    src.lib.auth.origin --> "src/app/api/domains/[id]/receiving/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.domains.service --> "src/app/api/domains/[id]/receiving/route" { getDomainForUser }
    src.lib.domains.receiving --> "src/app/api/domains/[id]/receiving/route" {
        receivingPresence,
        removeReceiving,
    }
    "src/lib/deliverability/mta-sts-guard" --> "src/app/api/domains/[id]/receiving/route" {
        assertMxChangeAllowed,
    }
    "src/lib/deliverability/mta-sts-block-response" --> "src/app/api/domains/[id]/receiving/route" {
        mtaStsBlockedResponse,
    }
    src.lib.cloudflare --> "src/app/api/domains/[id]/resend/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/domains/[id]/resend/route" { requireUser }
    src.lib.auth.admin --> "src/app/api/domains/[id]/resend/route" { canManageDomains }
    src.lib.auth.origin --> "src/app/api/domains/[id]/resend/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.domains.service --> "src/app/api/domains/[id]/resend/route" { getDomainForUser }
    "src/lib/email/resend-api" --> "src/app/api/domains/[id]/resend/route" {
        ResendRestrictedKeyError,
    }
    "src/lib/email/outbound-provider" --> "src/app/api/domains/[id]/resend/route" {
        getResendKeyStatus,
    }
    "src/lib/email/system-mail" --> "src/app/api/domains/[id]/resend/route" { sendSystemEmail }
    "src/lib/domains/resend-domain" --> "src/app/api/domains/[id]/resend/route" {
        getResendDomainView,
        setupResendDomain,
        verifyResendDomainView,
    }
    "src/lib/cloudflare-dns" --> "src/lib/domains/resend-domain" {
        createDnsRecord,
        deleteDnsRecord,
        listDnsRecords,
    }
    src.lib.domains.provision --> "src/lib/domains/resend-domain" { isManualZone }
    "src/lib/email/outbound-provider" --> "src/lib/domains/resend-domain" {
        getResendClient,
        getResendKeyStatus,
    }
    "src/lib/email/resend-api" --> "src/lib/domains/resend-domain" {
        ResendClient,
        createResendDomain,
        deleteResendDomain,
        findResendDomain,
        getResendDomain,
        resendClient,
        updateResendCapabilities,
        verifyResendDomain,
    }
    "src/lib/domains/receiving-dns" --> "src/lib/domains/resend-domain" { isInboundSmtpMx }
    "src/lib/email/resend-api-types.d" --> "src/lib/domains/resend-domain" {
        ResendDomain,
        ResendDomainRecord,
    }
    "src/lib/domains/types.d" --> "src/lib/domains/resend-domain" { DomainRow }
    "src/lib/domains/resend-domain-types.d" --> "src/lib/domains/resend-domain" { ResendDomainView }
    src.db.index --> "src/app/api/domains/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/domains/[id]/route" { domains }
    src.lib.cloudflare --> "src/app/api/domains/[id]/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/domains/[id]/route" { requireUser }
    src.lib.auth.admin --> "src/app/api/domains/[id]/route" { canManageDomains }
    src.lib.domains.service --> "src/app/api/domains/[id]/route" {
        dnsSkippedUpdate,
        getDomainForUser,
        removeDomainForUser,
    }
    src.lib.auth.origin --> "src/app/api/domains/[id]/route" { hasValidSessionMutationOrigin }
    "src/lib/deliverability/mta-sts-block-response" --> "src/app/api/domains/[id]/route" {
        mtaStsBlockedResponse,
    }
    src.db.index --> "src/app/api/domains/[id]/sending/route" { getDb }
    src.db.schema.index --> "src/app/api/domains/[id]/sending/route" { domains }
    src.lib.cloudflare --> "src/app/api/domains/[id]/sending/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/domains/[id]/sending/route" { requireUser }
    src.lib.auth.admin --> "src/app/api/domains/[id]/sending/route" { canManageDomains }
    src.lib.auth.origin --> "src/app/api/domains/[id]/sending/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.domains.service --> "src/app/api/domains/[id]/sending/route" { getDomainForUser }
    "src/lib/domains/adopt-zone" --> "src/app/api/domains/[id]/sending/route" {
        adoptCloudflareZone,
    }
    src.lib.domains.provision --> "src/app/api/domains/[id]/sending/route" { isManualZone }
    "src/lib/domains/cloudflare-sending" --> "src/app/api/domains/[id]/sending/route" {
        findCloudflareSending,
        removeCloudflareSending,
    }
    src.lib.aws.config --> "src/app/api/domains/[id]/sending/route" { getAwsConfig }
    src.lib.aws.ses --> "src/app/api/domains/[id]/sending/route" { getSesIdentity }
    "src/lib/aws/ses-sending" --> "src/app/api/domains/[id]/sending/route" { removeSesSending }
    "src/lib/domains/resend-domain" --> "src/app/api/domains/[id]/sending/route" {
        getResendDomainStatus,
        removeResendConfig,
    }
    "src/lib/domains/dns-setup" --> "src/app/api/domains/[id]/sending/route" {
        setupDomainDnsRecord,
    }
    "src/lib/domains/receiving-dns" --> "src/app/api/domains/[id]/sending/route" { MxConflictError }
    "src/lib/deliverability/mta-sts-block-response" --> "src/app/api/domains/[id]/sending/route" {
        mtaStsBlockedResponse,
    }
    src.db.index --> "src/lib/domains/cloudflare-sending" { getDb }
    src.db.schema.index --> "src/lib/domains/cloudflare-sending" { domains }
    "src/lib/cloudflare-api" --> "src/lib/domains/cloudflare-sending" {
        deleteSendingSubdomain,
        listSendingSubdomains,
    }
    src.lib.domains.provision --> "src/lib/domains/cloudflare-sending" { isManualZone }
    "src/lib/domains/sending-status" --> "src/lib/domains/cloudflare-sending" {
        findSendingSubdomain,
    }
    "src/lib/domains/types.d" --> "src/lib/domains/cloudflare-sending" { DomainRow }
    "src/lib/cloudflare-dns" --> "src/lib/aws/ses-sending" {
        createDnsRecord,
        deleteDnsRecord,
        listDnsRecords,
    }
    src.lib.domains.provision --> "src/lib/aws/ses-sending" { isManualZone }
    src.lib.aws.config --> "src/lib/aws/ses-sending" { requireAwsConfig }
    "src/lib/deliverability/ses-feed" --> "src/lib/aws/ses-sending" { attachSesFeedToIdentity }
    src.lib.aws.ses --> "src/lib/aws/ses-sending" {
        createSesIdentity,
        deleteSesIdentity,
        getSesAccount,
        getSesIdentity,
    }
    "src/lib/domains/types.d" --> "src/lib/aws/ses-sending" { DomainRow }
    "src/lib/aws/ses-sending-types.d" --> "src/lib/aws/ses-sending" { SesSendingView }
    src.lib.cloudflare --> "src/app/api/domains/[id]/ses/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/domains/[id]/ses/route" { requireUser }
    src.lib.auth.admin --> "src/app/api/domains/[id]/ses/route" { canManageDomains }
    src.lib.auth.origin --> "src/app/api/domains/[id]/ses/route" { hasValidSessionMutationOrigin }
    src.lib.aws.config --> "src/app/api/domains/[id]/ses/route" { getAwsConfig }
    "src/lib/aws/ses-sending" --> "src/app/api/domains/[id]/ses/route" {
        getSesSendingView,
        setupSesSending,
    }
    src.lib.aws.client --> "src/app/api/domains/[id]/ses/route" { AwsError }
    src.lib.domains.service --> "src/app/api/domains/[id]/ses/route" { getDomainForUser }
    "src/lib/email/system-mail" --> "src/app/api/domains/[id]/ses/route" { sendSystemEmail }
    src.lib.cloudflare --> "src/app/api/domains/[id]/tracking/route" { getEnv }
    src.lib.api.auth --> "src/app/api/domains/[id]/tracking/route" { requireSessionUser }
    src.lib.auth.admin --> "src/app/api/domains/[id]/tracking/route" { canManageDomains }
    src.lib.auth.origin --> "src/app/api/domains/[id]/tracking/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.domains.service --> "src/app/api/domains/[id]/tracking/route" { getDomainForUser }
    "src/lib/tracking/open-tracking" --> "src/app/api/domains/[id]/tracking/route" {
        TrackingHostsUnavailableError,
        getDomainTrackingHost,
        setDomainTrackingHost,
    }
    "src/lib/tracking/open-tracking-utils" --> "src/app/api/domains/[id]/tracking/route" {
        normalizeTrackingHost,
    }
    "src/lib/database-errors" --> "src/app/api/domains/[id]/tracking/route" {
        isUniqueConstraintError,
    }
    src.lib.auth.cookies --> src.app.api.domains.check.route { requireUser }
    src.lib.cloudflare --> src.app.api.domains.check.route { getEnv }
    src.lib.domains.preflight --> src.app.api.domains.check.route { preflightSetupDomain }
    src.lib.validators --> src.app.api.domains.check.route { setupDomainSchema }
    src.lib.cloudflare --> src.app.api.domains.route { getEnv }
    src.lib.auth.cookies --> src.app.api.domains.route { requireUser }
    src.lib.auth.admin --> src.app.api.domains.route { canManageDomains }
    src.lib.validators --> src.app.api.domains.route { addDomainSchema }
    src.lib.domains.service --> src.app.api.domains.route { addDomainForUser, listUserDomains }
    src.lib.domains.utils --> src.app.api.domains.route { domainListOwnerIds }
    "src/lib/dns-status" --> src.app.api.domains.route { DnsStatusSummary }
    "src/lib/domains/dns-view" --> src.app.api.domains.route { summariseDomainDns }
    src.lib.domains.errors --> src.app.api.domains.route { getDomainProvisioningError }
    "src/lib/deliverability/mta-sts-block-response" --> src.app.api.domains.route {
        mtaStsBlockedResponse,
    }
    src.lib.auth.origin --> src.app.api.domains.route { hasValidSessionMutationOrigin }
    src.lib.cloudflare --> "src/app/api/drafts/[id]/attachments/[attachmentId]/route" { getEnv }
    src.db.index --> "src/app/api/drafts/[id]/attachments/[attachmentId]/route" { getDb }
    src.db.schema.index --> "src/app/api/drafts/[id]/attachments/[attachmentId]/route" {
        agentDraftMetadata,
        messages,
    }
    src.lib.auth.cookies --> "src/app/api/drafts/[id]/attachments/[attachmentId]/route" {
        requireUser,
    }
    src.lib.email.attachments --> "src/app/api/drafts/[id]/attachments/[attachmentId]/route" {
        deleteMessageAttachment,
    }
    src.app.api.drafts.utils --> "src/app/api/drafts/[id]/attachments/[attachmentId]/route" {
        userOwnsDraft,
    }
    src.lib.email.sender --> src.app.api.drafts.utils { getAuthorizedSenderAddress }
    "src/app/api/drafts/types.d" --> src.app.api.drafts.utils { DraftPayload }
    src.lib.cloudflare --> "src/app/api/drafts/[id]/attachments/route" { getEnv }
    src.db.index --> "src/app/api/drafts/[id]/attachments/route" { getDb }
    src.db.schema.index --> "src/app/api/drafts/[id]/attachments/route" {
        agentDraftMetadata,
        messages,
    }
    src.lib.auth.cookies --> "src/app/api/drafts/[id]/attachments/route" { getCurrentUser }
    src.lib.auth.origin --> "src/app/api/drafts/[id]/attachments/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.email.attachments --> "src/app/api/drafts/[id]/attachments/route" {
        MAX_ATTACHMENT_COUNT,
        listMessageAttachments,
        storeMessageAttachments,
    }
    "src/lib/email/attachment-limits" --> "src/app/api/drafts/[id]/attachments/route" {
        outgoingSizeError,
        requestBodyLimit,
    }
    "src/lib/email/attachment-policy" --> "src/app/api/drafts/[id]/attachments/route" {
        getOutboundAttachmentMaxMb,
    }
    src.lib.http.request --> "src/app/api/drafts/[id]/attachments/route" { readFormDataBody }
    src.lib.http.errors --> "src/app/api/drafts/[id]/attachments/route" { RequestBodyTooLargeError }
    src.app.api.drafts.utils --> "src/app/api/drafts/[id]/attachments/route" { userOwnsDraft }
    "src/app/api/drafts/[id]/attachments/types.d" --> "src/app/api/drafts/[id]/attachments/route" {
        DraftAttachmentUploadParams,
    }
    src.lib.cloudflare --> "src/app/api/drafts/[id]/route" { getEnv }
    src.db.index --> "src/app/api/drafts/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/drafts/[id]/route" { agentDraftMetadata, messages }
    src.lib.auth.cookies --> "src/app/api/drafts/[id]/route" { requireUser }
    src.lib.email.parse --> "src/app/api/drafts/[id]/route" { buildSnippet }
    "src/app/api/drafts/[id]/types.d" --> "src/app/api/drafts/[id]/route" {
        DraftPayload,
        DraftRouteParams,
    }
    "src/app/api/drafts/[id]/utils" --> "src/app/api/drafts/[id]/route" { selectDraftWithBody }
    src.lib.http.request --> "src/app/api/drafts/[id]/route" { readJsonBody }
    src.lib.http.errors --> "src/app/api/drafts/[id]/route" { RequestBodyTooLargeError }
    src.app.api.drafts.utils --> "src/app/api/drafts/[id]/route" { getDraftSender, userOwnsDraft }
    src.lib.email.attachments --> "src/app/api/drafts/[id]/route" { listMessageAttachments }
    "src/lib/email/message-cleanup" --> "src/app/api/drafts/[id]/route" { deleteMessageWithObjects }
    src.lib.agent.schedule --> "src/app/api/drafts/[id]/route" { parseAgentScheduledAt }
    src.db.index --> "src/app/api/drafts/[id]/utils" { getDb }
    src.db.schema.index --> "src/app/api/drafts/[id]/utils" { messages }
    src.lib.cloudflare --> src.app.api.drafts.route { getEnv }
    src.db.index --> src.app.api.drafts.route { getDb }
    src.db.schema.index --> src.app.api.drafts.route { messages }
    src.lib.auth.cookies --> src.app.api.drafts.route { requireUser }
    src.lib.ids --> src.app.api.drafts.route { newId }
    src.lib.email.parse --> src.app.api.drafts.route { buildSnippet }
    src.lib.http.request --> src.app.api.drafts.route { readJsonBody }
    src.lib.email.attachments --> src.app.api.drafts.route { copyMessageAttachments }
    "src/lib/email/draft-access" --> src.app.api.drafts.route { isOthersDraft }
    src.lib.mailboxes.access --> src.app.api.drafts.route { getMailboxAccessLevel }
    src.lib.http.errors --> src.app.api.drafts.route { RequestBodyTooLargeError }
    "src/app/api/drafts/types.d" --> src.app.api.drafts.route { DraftPayload }
    src.app.api.drafts.utils --> src.app.api.drafts.route { getDraftSender }
    src.db.index --> "src/app/api/drive/attachments/[id]/content/route" { getDb }
    src.db.schema.index --> "src/app/api/drive/attachments/[id]/content/route" {
        messageAttachments,
    }
    src.lib.cloudflare --> "src/app/api/drive/attachments/[id]/content/route" { getEnv }
    src.lib.api.auth --> "src/app/api/drive/attachments/[id]/content/route" { requireSessionUser }
    src.lib.email.attachments --> "src/app/api/drive/attachments/[id]/content/route" {
        getAttachmentForUser,
    }
    src.lib.drive.auth --> "src/app/api/drive/attachments/[id]/content/route" { driveAccessError }
    src.lib.drive.content --> "src/app/api/drive/attachments/[id]/content/route" { streamDriveFile }
    "src/lib/drive/types.d" --> "src/app/api/drive/attachments/[id]/content/route" { DriveRow }
    "src/app/api/drive/items/[id]/types.d" --> "src/app/api/drive/attachments/[id]/content/route" {
        DriveItemParams,
    }
    src.db.index --> src.lib.drive.auth { getDb }
    src.lib.cloudflare --> src.lib.drive.auth { getEnv }
    src.lib.api.auth --> src.lib.drive.auth { requireSessionUser }
    src.lib.auth.origin --> src.lib.drive.auth { hasValidSessionMutationOrigin }
    "src/lib/http/content-type" --> src.lib.drive.content { getInlineContentType }
    src.lib.drive.utils --> src.lib.drive.content { driveContentDisposition, driveObjectKey }
    "src/lib/drive/types.d" --> src.lib.drive.content { DriveRow }
    src.db.index --> src.app.api.drive.attachments.route { getDb }
    src.db.schema.index --> src.app.api.drive.attachments.route { messageAttachments, messages }
    src.lib.drive.auth --> src.app.api.drive.attachments.route { authorizeDrive }
    src.lib.mailboxes.access --> src.app.api.drive.attachments.route {
        getMailboxAccessLevel,
        hasMailboxPermission,
    }
    "src/lib/drive/shared-objects" --> src.app.api.drive.attachments.route {
        deleteUnreferencedObjects,
    }
    src.db.schema.index --> src.app.api.drive.folders.route { driveItems }
    src.lib.drive.auth --> src.app.api.drive.folders.route { authorizeDrive }
    src.lib.drive.access --> src.app.api.drive.folders.route { withoutTrashedAncestors }
    src.lib.drive.auth --> src.app.api.drive.import.files.route { authorizeDrive }
    "src/lib/drive/import-store" --> src.app.api.drive.import.files.route {
        findEditableFolders,
        planImportFiles,
    }
    "src/lib/drive/import-store-types.d" --> src.app.api.drive.import.files.route {
        ImportFileOutcome,
    }
    src.lib.http.errors --> src.app.api.drive.import.files.route { RequestBodyTooLargeError }
    src.lib.http.request --> src.app.api.drive.import.files.route { readJsonBody }
    src.db.index --> "src/lib/drive/import-store" { getDb }
    src.db.schema.index --> "src/lib/drive/import-store" { driveItems, driveShares }
    "src/lib/calendar/import-store-utils" --> "src/lib/drive/import-store" {
        SELECT_CHUNK,
        STATEMENTS_PER_BATCH,
        chunk,
    }
    src.lib.ids --> "src/lib/drive/import-store" { newId }
    "src/lib/drive/import-utils" --> "src/lib/drive/import-store" {
        NESTED_TOO_DEEPLY,
        collisionCandidates,
        collisionPattern,
        importName,
        planImportFile,
    }
    "src/lib/drive/import-store-types.d" --> "src/lib/drive/import-store" {
        ImportFileInput,
        ImportFileOutcome,
        ImportFolderResult,
    }
    "src/lib/drive/import-types.d" --> "src/lib/drive/import-store" { KnownDriveItem }
    "src/lib/drive/types.d" --> "src/lib/drive/import-store" { DriveRow }
    src.lib.drive.utils --> "src/lib/drive/import-store" {
        DRIVE_MAX_DEPTH,
        DRIVE_MAX_FILE_BYTES,
        canEditDrive,
    }
    src.lib.drive.auth --> src.app.api.drive.import.folders.route { authorizeDrive }
    "src/lib/drive/import-store" --> src.app.api.drive.import.folders.route {
        ensureImportFolders,
        findEditableFolders,
    }
    "src/lib/drive/import-utils" --> src.app.api.drive.import.folders.route {
        MAX_IMPORT_FOLDERS,
        folderPrefixes,
    }
    src.lib.drive.utils --> src.app.api.drive.import.folders.route { DRIVE_MAX_DEPTH }
    src.lib.http.errors --> src.app.api.drive.import.folders.route { RequestBodyTooLargeError }
    src.lib.http.request --> src.app.api.drive.import.folders.route { readJsonBody }
    src.lib.drive.auth --> "src/app/api/drive/items/[id]/content/route" { authorizeDrive }
    src.lib.drive.access --> "src/app/api/drive/items/[id]/content/route" {
        getDriveItem,
        getDriveRole,
    }
    src.lib.drive.content --> "src/app/api/drive/items/[id]/content/route" { streamDriveFile }
    "src/app/api/drive/items/[id]/types.d" --> "src/app/api/drive/items/[id]/content/route" {
        DriveItemParams,
    }
    src.db.schema.index --> "src/app/api/drive/items/[id]/link/route" { driveItems }
    src.lib.ids --> "src/app/api/drive/items/[id]/link/route" { newId }
    src.lib.drive.auth --> "src/app/api/drive/items/[id]/link/route" { authorizeDrive }
    src.lib.drive.access --> "src/app/api/drive/items/[id]/link/route" { getDriveItem }
    "src/app/api/drive/items/[id]/types.d" --> "src/app/api/drive/items/[id]/link/route" {
        DriveItemParams,
    }
    src.db.schema.index --> "src/app/api/drive/items/[id]/route" { driveItems }
    src.lib.drive.auth --> "src/app/api/drive/items/[id]/route" { authorizeDrive }
    src.lib.drive.access --> "src/app/api/drive/items/[id]/route" {
        deleteDriveItems,
        getDriveItem,
        getDriveRole,
        toDriveItemDtos,
    }
    src.lib.drive.utils --> "src/app/api/drive/items/[id]/route" {
        canEditDrive,
        normalizeDriveName,
    }
    "src/app/api/drive/items/[id]/types.d" --> "src/app/api/drive/items/[id]/route" {
        DriveItemParams,
    }
    src.db.schema.index --> "src/app/api/drive/items/[id]/shares/route" { driveShares, users }
    src.lib.ids --> "src/app/api/drive/items/[id]/shares/route" { newId }
    src.lib.drive.auth --> "src/app/api/drive/items/[id]/shares/route" { authorizeDrive }
    src.lib.drive.access --> "src/app/api/drive/items/[id]/shares/route" { getDriveItem }
    "src/app/api/drive/items/[id]/types.d" --> "src/app/api/drive/items/[id]/shares/route" {
        DriveItemParams,
    }
    src.db.schema.index --> src.app.api.drive.items.bulk.route { driveItems }
    src.lib.drive.auth --> src.app.api.drive.items.bulk.route { authorizeDrive }
    src.lib.drive.access --> src.app.api.drive.items.bulk.route {
        deleteDriveItems,
        getDriveChain,
        getDriveItem,
        getDriveRole,
    }
    src.lib.drive.utils --> src.app.api.drive.items.bulk.route { canEditDrive }
    "src/lib/drive/types.d" --> src.app.api.drive.items.bulk.route { DriveRow }
    src.db.schema.index --> src.app.api.drive.items.route { driveItems, driveShares }
    src.lib.ids --> src.app.api.drive.items.route { newId }
    src.lib.drive.auth --> src.app.api.drive.items.route { authorizeDrive }
    src.lib.drive.access --> src.app.api.drive.items.route {
        getDriveChain,
        getDriveItem,
        getDriveRole,
        toDriveItemDtos,
        withoutTrashedAncestors,
    }
    src.lib.drive.utils --> src.app.api.drive.items.route {
        canEditDrive,
        normalizeDriveName,
        toDriveCrumbs,
    }
    src.lib.drive.categories --> src.app.api.drive.items.route {
        driveTypesCondition,
        parseDriveCategories,
    }
    src.lib.drive.attachments --> src.app.api.drive.items.route { listDriveAttachments }
    src.lib.drive.storage --> src.app.api.drive.items.route {
        getDriveStorageLimit,
        getDriveStorageUsed,
    }
    "src/lib/drive/types.d" --> src.app.api.drive.items.route { DriveRole }
    src.db.sql --> src.app.api.drive.items.route { containsLike }
    src.db.schema.index --> src.lib.drive.categories { driveItems }
    "src/lib/drive/category-names" --> src.lib.drive.categories {
        DRIVE_CATEGORIES,
        DriveCategory,
        isDriveCategory,
    }
    src.db.index --> src.lib.drive.attachments { getDb }
    src.db.schema.index --> src.lib.drive.attachments { messageAttachments, messages }
    "src/lib/email/draft-access" --> src.lib.drive.attachments {
        DRAFT_FILTER_PARAMS,
        draftsVisibleTo,
    }
    src.lib.mailboxes.access --> src.lib.drive.attachments {
        hasMailboxPermission,
        listAccessibleMailboxes,
    }
    src.lib.drive.categories --> src.lib.drive.attachments { DriveCategory, driveTypesCondition }
    "src/lib/drive/types.d" --> src.lib.drive.attachments { DriveItemDto }
    src.db.index --> "src/app/api/drive/owners/[id]/avatar/route" { getDb }
    src.db.schema.index --> "src/app/api/drive/owners/[id]/avatar/route" {
        driveItems,
        driveShares,
        users,
    }
    src.lib.cloudflare --> "src/app/api/drive/owners/[id]/avatar/route" { getEnv }
    src.lib.api.auth --> "src/app/api/drive/owners/[id]/avatar/route" { requireSessionUser }
    "src/lib/avatar-images" --> "src/app/api/drive/owners/[id]/avatar/route" {
        getAvatarImageResponse,
    }
    src.lib.drive.auth --> "src/app/api/drive/owners/[id]/avatar/route" { driveAccessError }
    "src/app/api/drive/items/[id]/types.d" --> "src/app/api/drive/owners/[id]/avatar/route" {
        DriveItemParams,
    }
    src.db.index --> "src/app/api/drive/public/[token]/route" { getDb }
    src.db.schema.index --> "src/app/api/drive/public/[token]/route" { driveItems }
    src.lib.cloudflare --> "src/app/api/drive/public/[token]/route" { getEnv }
    src.lib.drive.access --> "src/app/api/drive/public/[token]/route" {
        getDriveChain,
        getPublicDriveItem,
    }
    src.lib.drive.content --> "src/app/api/drive/public/[token]/route" { streamDriveFile }
    "src/app/api/drive/public/[token]/types.d" --> "src/app/api/drive/public/[token]/route" {
        DriveTokenParams,
    }
    src.db.schema.index --> "src/app/api/drive/upload/[id]/route" { driveItems, driveUploadParts }
    src.lib.drive.auth --> "src/app/api/drive/upload/[id]/route" { authorizeDrive }
    src.lib.drive.access --> "src/app/api/drive/upload/[id]/route" {
        getDriveItem,
        getDriveRole,
        toDriveItemDtos,
    }
    src.lib.drive.utils --> "src/app/api/drive/upload/[id]/route" {
        DRIVE_MAX_PARTS,
        canEditDrive,
        driveObjectKey,
    }
    "src/app/api/drive/items/[id]/types.d" --> "src/app/api/drive/upload/[id]/route" {
        DriveItemParams,
    }
    src.db.schema.index --> src.app.api.drive.upload.route { driveItems, driveUploadParts }
    src.lib.ids --> src.app.api.drive.upload.route { newId }
    src.lib.drive.auth --> src.app.api.drive.upload.route { authorizeDrive }
    src.lib.drive.access --> src.app.api.drive.upload.route {
        getDriveItem,
        getDriveRole,
        toDriveItemDtos,
    }
    src.lib.drive.storage --> src.app.api.drive.upload.route {
        getDriveStorageLimit,
        getDriveStorageUsed,
    }
    src.lib.drive.utils --> src.app.api.drive.upload.route {
        DRIVE_MAX_FILE_BYTES,
        DRIVE_PART_BYTES,
        DRIVE_UPLOAD_RESUME_MS,
        canEditDrive,
        driveObjectKey,
        normalizeDriveName,
    }
    src.db.index --> src.app.api.export.messages.route { getDb }
    src.lib.auth.cookies --> src.app.api.export.messages.route { requireUser }
    src.lib.cloudflare --> src.app.api.export.messages.route { getEnv }
    src.lib.export.mbox --> src.app.api.export.messages.route { exportMailboxToMbox }
    src.lib.mailboxes.access --> src.app.api.export.messages.route { getMailboxAccessLevel }
    src.db.index --> src.lib.export.mbox { getDb }
    src.db.schema.index --> src.lib.export.mbox { messages }
    "src/lib/email/draft-access" --> src.lib.export.mbox { draftsVisibleTo }
    src.db.index --> src.app.api.folders.route { getDb }
    src.db.schema.index --> src.app.api.folders.route { folders }
    src.lib.auth.cookies --> src.app.api.folders.route { requireUser }
    src.lib.cloudflare --> src.app.api.folders.route { getEnv }
    src.lib.ids --> src.app.api.folders.route { newId }
    src.lib.validators --> src.app.api.folders.route { folderSchema }
    src.app.api.folders.utils --> src.app.api.folders.route {
        getMailboxFolderAccess,
        listFoldersForMailbox,
    }
    src.lib.http.request --> src.app.api.folders.route { readJsonObject }
    src.db.index --> src.app.api.folders.utils { getDb }
    src.db.schema.index --> src.app.api.folders.utils { folders }
    "src/lib/auth/types.d" --> src.app.api.folders.utils { SessionUser }
    src.lib.mailboxes.access --> src.app.api.folders.utils { getMailboxAccessLevel }
    src.lib.auth.cookies --> "src/app/api/follow-ups/[id]/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/follow-ups/[id]/route" { getEnv }
    "src/lib/follow-ups/follow-up-utils" --> "src/app/api/follow-ups/[id]/route" {
        parseFollowUpDays,
    }
    "src/lib/follow-ups/service" --> "src/app/api/follow-ups/[id]/route" { updateFollowUp }
    src.db.index --> "src/app/api/follow-ups/route" { getDb }
    src.lib.auth.cookies --> "src/app/api/follow-ups/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/follow-ups/route" { getEnv }
    "src/lib/follow-ups/service" --> "src/app/api/follow-ups/route" { listDueFollowUps }
    src.lib.mailboxes.access --> "src/app/api/follow-ups/route" { getMailboxAccessLevel }
    src.lib.cloudflare --> "src/app/api/i/[file]/route" { getEnv }
    "src/lib/tracking/open-tracking" --> "src/app/api/i/[file]/route" { recordOpen }
    "src/lib/tracking/open-tracking-utils" --> "src/app/api/i/[file]/route" {
        TRACKING_PIXEL_GIF,
        TRACKING_PIXEL_HEADERS,
        parseTrackingToken,
    }
    src.db.index --> src.app.api.import.calendar.route { getDb }
    src.lib.auth.origin --> src.app.api.import.calendar.route { hasValidSessionMutationOrigin }
    "src/lib/calendar/api-auth" --> src.app.api.import.calendar.route { authorizeCalendarRequest }
    src.lib.calendar.colors --> src.app.api.import.calendar.route { normalizeCalendarColor }
    "src/lib/calendar/import-store" --> src.app.api.import.calendar.route {
        importCalendarGroups,
        listOwnAddresses,
    }
    "src/lib/calendar/import-store-utils" --> src.app.api.import.calendar.route {
        readCalendarImportBody,
    }
    "src/lib/calendar/invite-store" --> src.app.api.import.calendar.route {
        recipientInviteTimeZone,
    }
    src.lib.cloudflare --> src.app.api.import.calendar.route { getEnv }
    src.lib.http.errors --> src.app.api.import.calendar.route { RequestBodyTooLargeError }
    src.lib.http.request --> src.app.api.import.calendar.route { readJsonBody }
    src.lib.time.utils --> src.app.api.import.calendar.route { getRequestTimeZone }
    src.db.index --> src.app.api.import.contacts.route { getDb }
    src.lib.api.auth --> src.app.api.import.contacts.route { requireSessionUser }
    src.lib.auth.origin --> src.app.api.import.contacts.route { hasValidSessionMutationOrigin }
    src.lib.cloudflare --> src.app.api.import.contacts.route { getEnv }
    "src/lib/contacts/import-store" --> src.app.api.import.contacts.route {
        ContactDetailsUnavailableError,
        importContacts,
    }
    "src/lib/contacts/import-store-utils" --> src.app.api.import.contacts.route {
        readContactImportBody,
    }
    src.lib.http.errors --> src.app.api.import.contacts.route { RequestBodyTooLargeError }
    src.lib.http.request --> src.app.api.import.contacts.route { readJsonBody }
    src.lib.mailboxes.access --> src.app.api.import.contacts.route { getMailboxAccessLevel }
    src.lib.auth.cookies --> src.app.api.import.imap.folders.route { requireUser }
    src.lib.cloudflare --> src.app.api.import.imap.folders.route { getEnv }
    src.lib.http.errors --> src.app.api.import.imap.folders.route { RequestBodyTooLargeError }
    src.lib.http.request --> src.app.api.import.imap.folders.route { readJsonBody }
    src.lib.import.imap --> src.app.api.import.imap.folders.route { listImapFolders }
    "src/app/api/import/imap/folders/types.d" --> src.app.api.import.imap.folders.route {
        ImapFolderListRequest,
    }
    src.app.api.import.imap.folders.utils --> src.app.api.import.imap.folders.route {
        parseImapFolderListRequest,
    }
    "src/lib/import/imap-types.d" --> src.app.api.import.imap.folders.utils { ImapImportInput }
    "src/app/api/import/imap/folders/types.d" --> src.app.api.import.imap.folders.utils {
        ImapFolderListRequest,
    }
    src.db.index --> src.app.api.import.imap.route { getDb }
    src.db.schema.index --> src.app.api.import.imap.route { folders }
    src.lib.auth.cookies --> src.app.api.import.imap.route { requireUser }
    src.lib.cloudflare --> src.app.api.import.imap.route { getEnv }
    src.lib.http.errors --> src.app.api.import.imap.route { RequestBodyTooLargeError }
    src.lib.http.request --> src.app.api.import.imap.route { readJsonBody }
    "src/lib/import/imap-utils" --> src.app.api.import.imap.route { assertSafeImapHost }
    src.lib.import.jobs --> src.app.api.import.imap.route { createImapImportJob }
    src.lib.mailboxes.access --> src.app.api.import.imap.route { getMailboxAccessLevel }
    "src/app/api/import/imap/types.d" --> src.app.api.import.imap.route { ImapImportRequest }
    src.app.api.import.imap.utils --> src.app.api.import.imap.route { parseImapImportRequest }
    src.lib.import.destination --> src.app.api.import.imap.utils { parseImportDestination }
    "src/lib/import/destination-types.d" --> src.app.api.import.imap.utils { ImportDestination }
    "src/lib/import/jobs-types.d" --> src.app.api.import.imap.utils { ImapImportSpec }
    "src/app/api/import/imap/types.d" --> src.app.api.import.imap.utils { ImapImportRequest }
    src.lib.api.auth --> "src/app/api/import/jobs/[id]/resume/route" { requireSessionUser }
    src.lib.cloudflare --> "src/app/api/import/jobs/[id]/resume/route" { getEnv }
    src.lib.http.request --> "src/app/api/import/jobs/[id]/resume/route" { readJsonBody }
    src.lib.import.jobs --> "src/app/api/import/jobs/[id]/resume/route" { resumeImportJob }
    src.lib.api.auth --> "src/app/api/import/jobs/[id]/route" { requireSessionUser }
    src.lib.cloudflare --> "src/app/api/import/jobs/[id]/route" { getEnv }
    src.lib.import.jobs --> "src/app/api/import/jobs/[id]/route" { cancelOrDismissImportJob }
    src.lib.api.auth --> src.app.api.import.jobs.route { requireSessionUser }
    src.lib.cloudflare --> src.app.api.import.jobs.route { getEnv }
    src.lib.import.jobs --> src.app.api.import.jobs.route { listImportJobs }
    src.db.index --> src.app.api.import.messages.route { getDb }
    src.db.schema.index --> src.app.api.import.messages.route { folders }
    src.lib.auth.cookies --> src.app.api.import.messages.route { requireUser }
    src.lib.cloudflare --> src.app.api.import.messages.route { getEnv }
    src.lib.http.errors --> src.app.api.import.messages.route { RequestBodyTooLargeError }
    src.lib.import.destination --> src.app.api.import.messages.route { getImportMessageUserId }
    src.lib.import.jobs --> src.app.api.import.messages.route { createFileImportJob }
    src.lib.import.service --> src.app.api.import.messages.route { importMessagesToMailbox }
    src.lib.mailboxes.access --> src.app.api.import.messages.route { getMailboxAccessLevel }
    src.app.api.import.messages.utils --> src.app.api.import.messages.route { parseImportForm }
    src.lib.http.request --> src.app.api.import.messages.utils { readFormDataBody }
    src.lib.import.destination --> src.app.api.import.messages.utils {
        DEFAULT_IMPORT_DESTINATION,
        parseImportDestination,
    }
    "src/lib/import/destination-types.d" --> src.app.api.import.messages.utils { ImportDestination }
    src.lib.import.mbox --> src.app.api.import.messages.utils { splitMboxBytes }
    "src/lib/import/types.d" --> src.app.api.import.messages.utils { ImportMessageInput }
    src.lib.cloudflare --> src.app.api.inbound.resend.route { getEnv }
    src.lib.email.address --> src.app.api.inbound.resend.route {
        getEmailAddress,
        getEmailAddressList,
    }
    "src/lib/email/outbound-provider" --> src.app.api.inbound.resend.route { getResendClient }
    "src/lib/email/provider-intake" --> src.app.api.inbound.resend.route { intakeProviderMail }
    "src/lib/email/resend-api" --> src.app.api.inbound.resend.route { getReceivedEmail }
    src.lib.email.svix --> src.app.api.inbound.resend.route { verifySvixSignature }
    "src/lib/domains/resend-receiving" --> src.app.api.inbound.resend.route {
        getResendWebhookSecret,
    }
    src.lib.http.errors --> src.app.api.inbound.resend.route { RequestBodyTooLargeError }
    src.lib.http.request --> src.app.api.inbound.resend.route { readRawBody }
    src.db.index --> "src/lib/email/provider-intake" { getDb }
    src.db.schema.index --> "src/lib/email/provider-intake" { domains }
    src.lib.email.address --> "src/lib/email/provider-intake" { normalizeEmailAddress }
    "src/lib/email/inbound-attachments" --> "src/lib/email/provider-intake" {
        inboundAttachmentLimitReasonFromRaw,
    }
    src.lib.email.intake --> "src/lib/email/provider-intake" { intakeIncomingMail }
    "src/lib/email/provider-trace" --> "src/lib/email/provider-intake" {
        readHeaderMap,
        readSesTrace,
    }
    "src/lib/spam/types.d" --> "src/lib/email/provider-intake" { ProviderVerdicts }
    src.lib.cloudflare --> src.app.api.inbound.route { getEnv }
    src.lib.email.intake --> src.app.api.inbound.route { intakeIncomingMail }
    "src/lib/email/intake-signature" --> src.app.api.inbound.route {
        verifyInboundSignature,
        verifyInboundSignatureV2,
    }
    "src/lib/email/inbound-attachments" --> src.app.api.inbound.route {
        inboundAttachmentLimitReasonFromRaw,
    }
    src.lib.http.errors --> src.app.api.inbound.route { RequestBodyTooLargeError }
    src.lib.http.request --> src.app.api.inbound.route { readRawBody }
    "src/lib/email/provider-trace" --> src.app.api.inbound.route { readHeaderMap }
    src.lib.cloudflare --> src.app.api.inbound.ses.route { getEnv }
    src.lib.aws.config --> src.app.api.inbound.ses.route { requireAwsConfig }
    src.lib.aws.s3 --> src.app.api.inbound.ses.route { deleteObject, getObject }
    "src/lib/aws/ses-receiving" --> src.app.api.inbound.ses.route {
        SES_OBJECT_PREFIX,
        getSesReceivingState,
    }
    "src/lib/email/provider-intake" --> src.app.api.inbound.ses.route { intakeProviderMail }
    "src/lib/aws/ses-notification" --> src.app.api.inbound.ses.route {
        SnsEnvelope,
        parseSesNotification,
        safeEqual,
    }
    "src/lib/aws/sns-signature" --> src.app.api.inbound.ses.route { verifySnsSignature }
    src.lib.cloudflare --> src.app.api.licenses.activate.route { getEnv }
    src.lib.licenses.service --> src.app.api.licenses.activate.route { activateLicense }
    src.app.api.licenses.utils --> src.app.api.licenses.activate.route {
        getLicenseErrorResponse,
        getLicenseInstanceUrl,
        parseLicenseKeyRequest,
        requireLicenseAdmin,
    }
    src.lib.auth.admin --> src.app.api.licenses.utils { assertPrimaryAdmin }
    src.lib.auth.cookies --> src.app.api.licenses.utils { requireUser }
    "src/app/api/licenses/types.d" --> src.app.api.licenses.utils { LicenseKeyRequest }
    src.lib.cloudflare --> src.app.api.licenses.deactivate.route { getEnv }
    src.lib.licenses.service --> src.app.api.licenses.deactivate.route { deactivateLicense }
    src.app.api.licenses.utils --> src.app.api.licenses.deactivate.route {
        getLicenseErrorResponse,
        requireLicenseAdmin,
    }
    src.lib.cloudflare --> src.app.api.licenses.route { getEnv }
    src.lib.licenses.service --> src.app.api.licenses.route { getLicenseStatus }
    src.app.api.licenses.utils --> src.app.api.licenses.route {
        getLicenseErrorResponse,
        requireLicenseAdmin,
    }
    src.lib.cloudflare --> src.app.api.licenses.validate.route { getEnv }
    src.lib.licenses.service --> src.app.api.licenses.validate.route { validateLicense }
    src.app.api.licenses.utils --> src.app.api.licenses.validate.route {
        getLicenseErrorResponse,
        getLicenseInstanceUrl,
        parseLicenseKeyRequest,
        requireLicenseAdmin,
    }
    src.db.index --> "src/app/api/mailboxes/[id]/access/route" { getDb }
    src.db.schema.index --> "src/app/api/mailboxes/[id]/access/route" { mailboxAccess, users }
    src.app.api.accounts.utils --> "src/app/api/mailboxes/[id]/access/route" {
        requireTeamSharingAdmin,
    }
    src.lib.ids --> "src/app/api/mailboxes/[id]/access/route" { newId }
    src.lib.validators --> "src/app/api/mailboxes/[id]/access/route" { mailboxAccessSchema }
    "src/app/api/mailboxes/[id]/access/types.d" --> "src/app/api/mailboxes/[id]/access/route" {
        MailboxAccessRouteParams,
    }
    "src/app/api/mailboxes/[id]/access/utils" --> "src/app/api/mailboxes/[id]/access/route" {
        getSharedMailboxForAdmin,
    }
    src.db.index --> "src/app/api/mailboxes/[id]/access/utils" { getDb }
    src.db.schema.index --> "src/app/api/mailboxes/[id]/access/utils" { mailboxes }
    "src/lib/deliverability/report-address" --> "src/app/api/mailboxes/[id]/aliases/route" {
        isReportAddressReserved,
    }
    src.db.index --> "src/app/api/mailboxes/[id]/aliases/route" { getDb }
    src.db.schema.index --> "src/app/api/mailboxes/[id]/aliases/route" {
        domains,
        mailboxAliases,
        mailboxes,
    }
    src.lib.auth.cookies --> "src/app/api/mailboxes/[id]/aliases/route" { requireUser }
    src.lib.cloudflare --> "src/app/api/mailboxes/[id]/aliases/route" { getEnv }
    "src/lib/cloudflare-api" --> "src/app/api/mailboxes/[id]/aliases/route" {
        deleteEmailRoutingRuleForAddress,
        ensureEmailRoutingRuleToWorker,
    }
    "src/lib/email/recipient-address" --> "src/app/api/mailboxes/[id]/aliases/route" {
        normalizeRecipientLocalPart,
        parseRecipientAddress,
    }
    src.lib.ids --> "src/app/api/mailboxes/[id]/aliases/route" { newId }
    "src/lib/mailboxes/domain-addresses" --> "src/app/api/mailboxes/[id]/aliases/route" {
        getMailboxDomainAddresses,
    }
    "src/lib/mailboxes/settings-access" --> "src/app/api/mailboxes/[id]/aliases/route" {
        getMailboxSettingsAccess,
    }
    src.lib.validators --> "src/app/api/mailboxes/[id]/aliases/route" {
        mailboxAliasBodySchema,
        updateMailboxAliasSchema,
    }
    "src/app/api/mailboxes/[id]/types.d" --> "src/app/api/mailboxes/[id]/aliases/route" {
        MailboxRouteParams,
    }
    src.db.index --> "src/lib/mailboxes/settings-access" { getDb }
    src.db.schema.index --> "src/lib/mailboxes/settings-access" { mailboxes, users }
    src.lib.auth.admin --> "src/lib/mailboxes/settings-access" {
        canManageUserAccount,
        canManageUsers,
    }
    "src/lib/auth/types.d" --> "src/lib/mailboxes/settings-access" { SessionUser }
    src.lib.licenses.service --> "src/lib/mailboxes/settings-access" { getLicenseEntitlements }
    src.lib.mailboxes.access --> "src/lib/mailboxes/settings-access" { getMailboxAccessLevel }
    src.db.index --> "src/app/api/mailboxes/[id]/avatar/route" { getDb }
    src.db.schema.index --> "src/app/api/mailboxes/[id]/avatar/route" { domains, mailboxes, users }
    src.lib.auth.cookies --> "src/app/api/mailboxes/[id]/avatar/route" { requireUser }
    src.lib.cloudflare --> "src/app/api/mailboxes/[id]/avatar/route" { getEnv }
    "src/lib/avatar-images" --> "src/app/api/mailboxes/[id]/avatar/route" {
        getAvatarImageResponse,
        getOptimizedAvatarFiles,
        storeAvatarImages,
    }
    "src/lib/mailboxes/settings-access" --> "src/app/api/mailboxes/[id]/avatar/route" {
        getMailboxSettingsAccess,
    }
    src.app.api.profile.avatar.utils --> "src/app/api/mailboxes/[id]/avatar/route" { avatarKeyFor }
    "src/lib/profile/identity-utils" --> "src/app/api/mailboxes/[id]/avatar/route" {
        tracksAccountIdentity,
    }
    src.lib.profile.sync --> "src/app/api/mailboxes/[id]/avatar/route" { syncPersonalIdentity }
    "src/app/api/mailboxes/[id]/avatar/types.d" --> "src/app/api/mailboxes/[id]/avatar/route" {
        MailboxAvatarRouteParams,
    }
    "src/app/api/mailboxes/[id]/avatar/utils" --> "src/app/api/mailboxes/[id]/avatar/route" {
        mailboxAvatarKeyFor,
    }
    src.db.index --> "src/app/api/mailboxes/[id]/promotions/route" { getDb }
    src.db.schema.index --> "src/app/api/mailboxes/[id]/promotions/route" {
        mailboxPromotionSettings,
    }
    src.lib.api.auth --> "src/app/api/mailboxes/[id]/promotions/route" { requireSessionUser }
    src.lib.auth.origin --> "src/app/api/mailboxes/[id]/promotions/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.cloudflare --> "src/app/api/mailboxes/[id]/promotions/route" { getEnv }
    "src/lib/database-errors" --> "src/app/api/mailboxes/[id]/promotions/route" {
        isMissingColumnError,
        isMissingTableError,
    }
    src.lib.mailboxes.access --> "src/app/api/mailboxes/[id]/promotions/route" {
        getMailboxAccessLevel,
    }
    "src/lib/promotions/mode-utils" --> "src/app/api/mailboxes/[id]/promotions/route" {
        backfillPatchForModeChange,
        describeBackfill,
        parseModeBody,
    }
    src.db.index --> "src/app/api/mailboxes/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/mailboxes/[id]/route" { mailboxes, users }
    src.lib.auth.cookies --> "src/app/api/mailboxes/[id]/route" { requireUser }
    src.lib.cloudflare --> "src/app/api/mailboxes/[id]/route" { getEnv }
    "src/lib/mailboxes/settings-access" --> "src/app/api/mailboxes/[id]/route" {
        getMailboxSettingsAccess,
    }
    "src/lib/mailboxes/domain-addresses" --> "src/app/api/mailboxes/[id]/route" {
        ensureMailboxDomainRouting,
        removeMailboxDomainRouting,
    }
    "src/lib/profile/identity-utils" --> "src/app/api/mailboxes/[id]/route" {
        isPrimaryMailbox,
        tracksAccountIdentity,
    }
    src.lib.profile.sync --> "src/app/api/mailboxes/[id]/route" { syncPersonalIdentity }
    src.lib.validators --> "src/app/api/mailboxes/[id]/route" { updateMailboxSchema }
    "src/app/api/mailboxes/[id]/types.d" --> "src/app/api/mailboxes/[id]/route" {
        MailboxRouteParams,
    }
    "src/app/api/mailboxes/[id]/utils" --> "src/app/api/mailboxes/[id]/route" {
        getMailboxUpdateValues,
        selectMailboxById,
    }
    src.lib.auth.origin --> "src/app/api/mailboxes/[id]/route" { hasValidSessionMutationOrigin }
    src.db.schema.index --> "src/app/api/mailboxes/[id]/utils" { domains, mailboxes, users }
    src.db.index --> "src/app/api/mailboxes/[id]/utils" { getDb }
    "src/app/api/mailboxes/[id]/types.d" --> "src/app/api/mailboxes/[id]/utils" {
        MailboxUpdateValues,
    }
    "src/lib/deliverability/report-address" --> src.app.api.mailboxes.route {
        isReportAddressReserved,
    }
    src.lib.cloudflare --> src.app.api.mailboxes.route { getEnv }
    src.db.index --> src.app.api.mailboxes.route { getDb }
    src.db.schema.index --> src.app.api.mailboxes.route {
        domains,
        mailboxAliases,
        mailboxes,
        users,
    }
    src.lib.auth.cookies --> src.app.api.mailboxes.route { requireUser }
    src.lib.ids --> src.app.api.mailboxes.route { newId }
    src.lib.licenses.service --> src.app.api.mailboxes.route { getLicenseEntitlements }
    "src/lib/profile/identity-utils" --> src.app.api.mailboxes.route { tracksAccountIdentity }
    src.lib.validators --> src.app.api.mailboxes.route { mailboxSchema }
    "src/lib/mailboxes/domain-addresses" --> src.app.api.mailboxes.route {
        ensureMailboxDomainRouting,
        getMailboxDomainAddresses,
    }
    "src/lib/email/recipient-address" --> src.app.api.mailboxes.route {
        normalizeRecipientLocalPart,
    }
    src.app.api.mailboxes.utils --> src.app.api.mailboxes.route { ensurePersonalMailbox }
    src.db.index --> src.app.api.mailboxes.utils { AppDatabase }
    src.db.schema.index --> src.app.api.mailboxes.utils { domains, mailboxes }
    "src/lib/cloudflare-api" --> src.app.api.mailboxes.utils { ensureEmailRoutingRuleToWorker }
    "src/lib/mailboxes/domain-addresses" --> src.app.api.mailboxes.utils {
        ensureMailboxDomainRouting,
    }
    src.lib.ids --> src.app.api.mailboxes.utils { newId }
    src.lib.mailboxes.access --> src.app.api.mailboxes.utils { listAccessibleMailboxes }
    "src/lib/deliverability/report-address" --> src.app.api.mailboxes.utils {
        isReportAddressReserved,
    }
    "src/lib/auth/types.d" --> src.app.api.mailboxes.utils { SessionUser }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/route" {
        getCurrentUser,
    }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/route" {
        getEnv,
    }
    src.lib.email.attachments --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/route" {
        assessStoredAttachment,
        getAttachmentForUser,
    }
    "src/lib/http/content-type" --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/route" {
        getInlineContentType,
    }
    "src/app/api/messages/[messageId]/attachments/[attachmentId]/types.d" --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/route" {
        AttachmentRouteParams,
    }
    "src/app/api/messages/[messageId]/attachments/[attachmentId]/utils" --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/route" {
        getAttachmentContentDisposition,
    }
    src.db.schema.index --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/save-to-drive/route" {
        driveItems,
    }
    src.lib.ids --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/save-to-drive/route" {
        newId,
    }
    src.lib.drive.auth --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/save-to-drive/route" {
        authorizeDrive,
    }
    src.lib.drive.access --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/save-to-drive/route" {
        toDriveItemDtos,
    }
    src.lib.drive.storage --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/save-to-drive/route" {
        getDriveStorageLimit,
        getDriveStorageUsed,
    }
    src.lib.drive.utils --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/save-to-drive/route" {
        DRIVE_MAX_FILE_BYTES,
        normalizeDriveName,
    }
    src.lib.email.attachments --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/save-to-drive/route" {
        getAttachmentForUser,
    }
    "src/app/api/messages/[messageId]/attachments/[attachmentId]/save-to-drive/types.d" --> "src/app/api/messages/[messageId]/attachments/[attachmentId]/save-to-drive/route" {
        SaveToDriveRouteParams,
    }
    src.db.index --> "src/app/api/messages/[messageId]/authentication/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/authentication/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/authentication/route" {
        getCurrentUser,
    }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/authentication/route" { getEnv }
    src.lib.email.address --> "src/app/api/messages/[messageId]/authentication/route" {
        getEmailAddress,
    }
    "src/lib/email/draft-access" --> "src/app/api/messages/[messageId]/authentication/route" {
        isOthersDraft,
    }
    "src/lib/email/provider-trace" --> "src/app/api/messages/[messageId]/authentication/route" {
        readSesAuthentication,
    }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/authentication/route" {
        getMailboxAccessLevel,
    }
    "src/lib/email/authentication-types.d" --> "src/app/api/messages/[messageId]/authentication/route" {
        MessageAuthenticationResponse,
    }
    "src/app/api/messages/[messageId]/authentication/types.d" --> "src/app/api/messages/[messageId]/authentication/route" {
        MessageAuthenticationRouteParams,
    }
    src.db.index --> "src/app/api/messages/[messageId]/cancel-schedule/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/cancel-schedule/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/cancel-schedule/route" {
        getCurrentUser,
    }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/cancel-schedule/route" { getEnv }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/cancel-schedule/route" {
        getMailboxAccessLevel,
    }
    "src/lib/email/draft-access" --> "src/app/api/messages/[messageId]/cancel-schedule/route" {
        isOthersDraft,
    }
    src.lib.email.scheduled --> "src/app/api/messages/[messageId]/cancel-schedule/route" {
        cancelScheduledSend,
        getScheduledTime,
    }
    src.db.index --> "src/app/api/messages/[messageId]/category/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/category/route" { messages }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/category/route" { getEnv }
    src.lib.promotions.refile --> "src/app/api/messages/[messageId]/category/route" {
        refileSenderMessages,
        setSenderOverride,
    }
    "src/lib/promotions/refile-utils" --> "src/app/api/messages/[messageId]/category/route" {
        parseCategoryMoveBody,
        targetOf,
    }
    "src/lib/promotions/route-guards" --> "src/app/api/messages/[messageId]/category/route" {
        MIGRATION_REQUIRED,
        authorizeMutation,
        checkManagedMailbox,
        isMissingSchema,
    }
    src.db.index --> src.lib.promotions.refile { getDb }
    src.db.schema.index --> src.lib.promotions.refile { mailboxSenderPreferences, messages }
    src.lib.ids --> src.lib.promotions.refile { newId }
    "src/lib/promotions/refile-utils" --> src.lib.promotions.refile {
        MAX_REFILE_ROWS,
        REFILE_CHUNK_SIZE,
        RefileTarget,
        chunk,
        refileCutoff,
    }
    src.db.index --> "src/lib/promotions/route-guards" { getDb }
    src.lib.api.auth --> "src/lib/promotions/route-guards" { requireSessionUser }
    src.lib.auth.origin --> "src/lib/promotions/route-guards" { hasValidSessionMutationOrigin }
    "src/lib/database-errors" --> "src/lib/promotions/route-guards" {
        isMissingColumnError,
        isMissingTableError,
    }
    src.lib.mailboxes.access --> "src/lib/promotions/route-guards" { getMailboxAccessLevel }
    src.lib.promotions.settings --> "src/lib/promotions/route-guards" { loadPromotionModes }
    src.db.index --> "src/app/api/messages/[messageId]/follow-up/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/follow-up/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/follow-up/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/follow-up/route" { getEnv }
    "src/lib/email/draft-access" --> "src/app/api/messages/[messageId]/follow-up/route" {
        isOthersDraft,
    }
    "src/lib/follow-ups/follow-up-utils" --> "src/app/api/messages/[messageId]/follow-up/route" {
        parseFollowUpDays,
    }
    "src/lib/database-errors" --> "src/app/api/messages/[messageId]/follow-up/route" {
        isMissingTableError,
    }
    "src/lib/follow-ups/service" --> "src/app/api/messages/[messageId]/follow-up/route" {
        getMessageFollowUp,
        setFollowUp,
        updateFollowUp,
    }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/follow-up/route" {
        getMailboxAccessLevel,
    }
    src.db.index --> "src/app/api/messages/[messageId]/invite/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/invite/route" {
        calendarEvents,
        messages,
    }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/invite/route" { getCurrentUser }
    "src/lib/calendar/api-auth" --> "src/app/api/messages/[messageId]/invite/route" {
        authorizeCalendarRequest,
        calendarKeyCanSendInvitations,
    }
    "src/lib/api/key-auth-types.d" --> "src/app/api/messages/[messageId]/invite/route" {
        ApiAuthResult,
    }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/invite/route" { getEnv }
    src.lib.calendar.invite --> "src/app/api/messages/[messageId]/invite/route" {
        InviteResponse,
        ParsedInvite,
        buildCounterIcs,
        buildReplyIcs,
        buildReplyText,
        parseCounterProposal,
        parseInvite,
    }
    "src/lib/calendar/invite-attachment" --> "src/app/api/messages/[messageId]/invite/route" {
        MAX_INVITE_BYTES,
        findInviteAttachment,
    }
    "src/lib/calendar/invite-rules" --> "src/app/api/messages/[messageId]/invite/route" {
        addExcludedOccurrence,
        normalizeInviteSender,
        planInviteAnswer,
    }
    "src/lib/calendar/invite-store" --> "src/app/api/messages/[messageId]/invite/route" {
        inviteEventId,
        inviteEventValues,
        recipientInviteTimeZone,
        sameInviteSender,
        upsertEventOverride,
    }
    src.lib.auth.origin --> "src/app/api/messages/[messageId]/invite/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.email.address --> "src/app/api/messages/[messageId]/invite/route" {
        getEmailAddress,
        splitEmailAddressList,
    }
    src.lib.email.attachments --> "src/app/api/messages/[messageId]/invite/route" {
        getAttachmentForUser,
        listMessageAttachments,
    }
    src.lib.email.send --> "src/app/api/messages/[messageId]/invite/route" { sendEmail }
    src.lib.time.utils --> "src/app/api/messages/[messageId]/invite/route" { getRequestTimeZone }
    "src/app/api/messages/[messageId]/invite/types.d" --> "src/app/api/messages/[messageId]/invite/route" {
        InviteRouteParams,
    }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/metadata/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/metadata/route" { getEnv }
    src.lib.email.inbound --> "src/app/api/messages/[messageId]/metadata/route" {
        getMessageMetadataForUser,
    }
    "src/app/api/messages/[messageId]/metadata/types.d" --> "src/app/api/messages/[messageId]/metadata/route" {
        MessageMetadataRouteParams,
    }
    "src/lib/database-errors" --> "src/app/api/messages/[messageId]/notes/[noteId]/route" {
        isMissingTableError,
    }
    src.lib.notes.service --> "src/app/api/messages/[messageId]/notes/[noteId]/route" {
        deleteConversationNote,
        updateConversationNote,
    }
    "src/app/api/messages/[messageId]/notes/utils" --> "src/app/api/messages/[messageId]/notes/[noteId]/route" {
        loadNoteConversation,
        migrationRequired,
        noteChangeError,
        readNoteHtml,
    }
    src.db.index --> src.lib.notes.service { AppDatabase }
    src.db.schema.index --> src.lib.notes.service { conversationNotes, messages, users }
    src.lib.mailboxes.access --> src.lib.notes.service { getMailboxAccessLevel }
    "src/lib/email/draft-access" --> src.lib.notes.service { isOthersDraft }
    src.lib.ids --> src.lib.notes.service { newId }
    "src/lib/db-params" --> src.lib.notes.service { selectInBatches }
    "src/lib/auth/types.d" --> src.lib.notes.service { SessionUser }
    "src/lib/notes/note-permissions" --> src.lib.notes.service { canDeleteNote, canEditNote }
    "src/lib/notes/types.d" --> src.lib.notes.service {
        ConversationNote,
        NoteChangeResult,
        NoteConversation,
    }
    src.db.index --> "src/app/api/messages/[messageId]/notes/utils" { AppDatabase, getDb }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/notes/utils" { getCurrentUser }
    "src/lib/auth/types.d" --> "src/app/api/messages/[messageId]/notes/utils" { SessionUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/notes/utils" { getEnv }
    src.lib.notes.service --> "src/app/api/messages/[messageId]/notes/utils" {
        CONVERSATION_NOTE_MAX_LENGTH,
        conversationForUser,
    }
    "src/lib/notes/types.d" --> "src/app/api/messages/[messageId]/notes/utils" { NoteConversation }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/notes/avatar/[userId]/route" { getEnv }
    "src/lib/avatar-images" --> "src/app/api/messages/[messageId]/notes/avatar/[userId]/route" {
        getAvatarImageResponse,
    }
    src.lib.notes.service --> "src/app/api/messages/[messageId]/notes/avatar/[userId]/route" {
        noteAuthorAvatarKey,
    }
    "src/app/api/messages/[messageId]/notes/utils" --> "src/app/api/messages/[messageId]/notes/avatar/[userId]/route" {
        loadNoteConversation,
    }
    "src/lib/database-errors" --> "src/app/api/messages/[messageId]/notes/route" {
        isMissingTableError,
    }
    src.lib.notes.service --> "src/app/api/messages/[messageId]/notes/route" {
        addConversationNote,
        listConversationNotes,
    }
    "src/app/api/messages/[messageId]/notes/utils" --> "src/app/api/messages/[messageId]/notes/route" {
        loadNoteConversation,
        migrationRequired,
        readNoteHtml,
    }
    src.db.index --> "src/app/api/messages/[messageId]/opens/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/opens/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/opens/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/opens/route" { getEnv }
    "src/lib/database-errors" --> "src/app/api/messages/[messageId]/opens/route" {
        isMissingTableError,
    }
    "src/lib/email/draft-access" --> "src/app/api/messages/[messageId]/opens/route" {
        isOthersDraft,
    }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/opens/route" {
        getMailboxAccessLevel,
    }
    "src/lib/tracking/open-tracking" --> "src/app/api/messages/[messageId]/opens/route" {
        getMessageTrackingSummary,
    }
    src.db.index --> "src/app/api/messages/[messageId]/original/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/original/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/original/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/original/route" { getEnv }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/original/route" {
        getMailboxAccessLevel,
    }
    "src/lib/email/draft-access" --> "src/app/api/messages/[messageId]/original/route" {
        isOthersDraft,
    }
    "src/app/api/messages/[messageId]/original/types.d" --> "src/app/api/messages/[messageId]/original/route" {
        MessageOriginalRouteParams,
    }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/read/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/read/route" { getCurrentUser }
    src.lib.user --> "src/app/api/messages/[messageId]/read/route" { markMessageAsReadForUser }
    src.db.index --> "src/app/api/messages/[messageId]/reschedule/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/reschedule/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/reschedule/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/reschedule/route" { getEnv }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/reschedule/route" {
        getMailboxAccessLevel,
    }
    src.lib.email.scheduled --> "src/app/api/messages/[messageId]/reschedule/route" {
        getScheduledTime,
        rescheduleScheduledSend,
    }
    src.lib.email.send --> "src/app/api/messages/[messageId]/reschedule/route" {
        enqueueOutboundJob,
    }
    "src/app/api/messages/[messageId]/reschedule/types.d" --> "src/app/api/messages/[messageId]/reschedule/route" {
        RescheduleMessagePayload,
    }
    "src/app/api/messages/[messageId]/reschedule/utils" --> "src/app/api/messages/[messageId]/reschedule/route" {
        getRescheduledAt,
    }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/route" { getEnv }
    src.lib.email.inbound --> "src/app/api/messages/[messageId]/route" { getMessageWithBodyForUser }
    src.db.index --> "src/app/api/messages/[messageId]/send-now/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/send-now/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/send-now/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/send-now/route" { getEnv }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/send-now/route" {
        getMailboxAccessLevel,
    }
    src.lib.email.send --> "src/app/api/messages/[messageId]/send-now/route" {
        sendScheduledMessageNow,
    }
    src.db.index --> "src/app/api/messages/[messageId]/send-status/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/send-status/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/send-status/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/send-status/route" { getEnv }
    "src/lib/email/draft-access" --> "src/app/api/messages/[messageId]/send-status/route" {
        isOthersDraft,
    }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/send-status/route" {
        getMailboxAccessLevel,
    }
    src.db.index --> "src/app/api/messages/[messageId]/snooze/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/snooze/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/snooze/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/snooze/route" { getEnv }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/snooze/route" {
        getMailboxAccessLevel,
    }
    "src/app/api/messages/[messageId]/snooze/types.d" --> "src/app/api/messages/[messageId]/snooze/route" {
        SnoozeMessagePayload,
    }
    "src/app/api/messages/[messageId]/snooze/utils" --> "src/app/api/messages/[messageId]/snooze/route" {
        getSnoozedUntil,
    }
    src.lib.http.request --> "src/app/api/messages/[messageId]/snooze/route" { readJsonObject }
    src.db.index --> "src/app/api/messages/[messageId]/star/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/star/route" { messages }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/star/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/star/route" { getEnv }
    "src/lib/email/draft-access" --> "src/app/api/messages/[messageId]/star/route" { isOthersDraft }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/star/route" {
        getMailboxAccessLevel,
    }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/status/route" { getEnv }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/status/route" { getCurrentUser }
    src.lib.user --> "src/app/api/messages/[messageId]/status/route" { updateMessageStatusForUser }
    "src/app/api/messages/[messageId]/status/types.d" --> "src/app/api/messages/[messageId]/status/route" {
        MessageStatusPayload,
    }
    "src/app/api/messages/[messageId]/status/utils" --> "src/app/api/messages/[messageId]/status/route" {
        isAllowedMessageStatus,
    }
    src.lib.http.request --> "src/app/api/messages/[messageId]/status/route" { readJsonObject }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/thread/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/thread/route" { getEnv }
    "src/lib/email/thread-view" --> "src/app/api/messages/[messageId]/thread/route" {
        getMessageThreadForUser,
    }
    src.db.index --> "src/lib/email/thread-view" { getDb }
    src.db.schema.index --> "src/lib/email/thread-view" { messageAttachments, messages }
    src.lib.contacts.service --> "src/lib/email/thread-view" { getContactCardMap }
    src.lib.contacts.utils --> "src/lib/email/thread-view" { getPartyDisplayName }
    src.lib.email.address --> "src/lib/email/thread-view" {
        getFirstEmailAddressEntry,
        normalizeEmailAddress,
    }
    "src/lib/email/draft-access" --> "src/lib/email/thread-view" { draftsVisibleTo, isOthersDraft }
    src.lib.mailboxes.access --> "src/lib/email/thread-view" { getMailboxAccessLevel }
    "src/lib/auth/types.d" --> "src/lib/email/thread-view" { SessionUser }
    src.db.index --> "src/app/api/messages/[messageId]/unsubscribe/route" { getDb }
    src.db.schema.index --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        domains,
        mailboxes,
        messages,
    }
    src.lib.auth.cookies --> "src/app/api/messages/[messageId]/unsubscribe/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/messages/[messageId]/unsubscribe/route" { getEnv }
    src.lib.email.address --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        getEmailAddress,
    }
    "src/lib/email/outbound-provider" --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        getOutboundProviderConfig,
        sendThroughProvider,
    }
    src.lib.email.unsubscribe --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        extractUnsubscribeLinkFromBody,
        getUnsubscribeUrlFromRawR2Key,
        parseMailtoUnsubscribe,
    }
    src.lib.promotions.subscriptions --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        recordUnsubscribed,
    }
    "src/lib/promotions/classify-utils" --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        toSenderAddress,
    }
    src.lib.mailboxes.audit --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        createAuditLog,
    }
    src.lib.mailboxes.access --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        getMailboxAccessLevel,
    }
    "src/app/api/messages/[messageId]/unsubscribe/types.d" --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        MailtoUnsubscribeTarget,
        UnsubscribePayload,
        UnsubscribeRouteParams,
    }
    "src/app/api/messages/[messageId]/unsubscribe/utils" --> "src/app/api/messages/[messageId]/unsubscribe/route" {
        allowUnsubscribeRequest,
        postOneClickUnsubscribe,
        senderTrashCondition,
    }
    src.db.sql --> "src/app/api/messages/[messageId]/unsubscribe/utils" { LIKE_ESCAPE, escapeLike }
    src.db.schema.index --> "src/app/api/messages/[messageId]/unsubscribe/utils" { messages }
    "src/lib/security/public-url" --> "src/app/api/messages/[messageId]/unsubscribe/utils" {
        assertResolvesPublic,
        isPublicHttpsUrl,
    }
    src.lib.auth.cookies --> src.app.api.messages.actions.route { getCurrentUser }
    src.lib.cloudflare --> src.app.api.messages.actions.route { getEnv }
    src.lib.messages.actions.service --> src.app.api.messages.actions.route {
        MessageActionError,
        applyMessageActionForUser,
        undoMessageActionForUser,
    }
    "src/lib/messages/actions/types.d" --> src.app.api.messages.actions.route { MessageActionInput }
    src.db.index --> src.lib.messages.actions.service { AppDatabase, getDb }
    src.db.dialect --> src.lib.messages.actions.service { schemaDialect }
    src.db.schema.index --> src.lib.messages.actions.service { folders, messages }
    "src/lib/auth/types.d" --> src.lib.messages.actions.service { SessionUser }
    "src/lib/email/draft-access" --> src.lib.messages.actions.service { isOthersDraft }
    src.lib.mailboxes.audit --> src.lib.messages.actions.service { createAuditLogs }
    src.lib.mailboxes.access --> src.lib.messages.actions.service { getMailboxAccessLevel }
    "src/lib/mailboxes/types.d" --> src.lib.messages.actions.service { MailboxAccessLevel }
    src.lib.spam.feedback --> src.lib.messages.actions.service { applySpamFeedback }
    src.lib.messages.actions.claims --> src.lib.messages.actions.service {
        claimMessageActionUndoToken,
        releaseMessageActionUndoClaim,
    }
    src.lib.messages.actions.definitions --> src.lib.messages.actions.service {
        MessageActionTarget,
        actionNeedsManage,
        getChangedStateFields,
        getMessageActionPatch,
        isReversibleMessageAction,
        planUndoRecord,
        recordHasChanges,
        snapshotMessageState,
    }
    src.lib.messages.actions.token --> src.lib.messages.actions.service {
        MAX_UNDO_AGE_MS,
        signUndoTokenForEnv,
        verifyUndoTokenForEnv,
    }
    "src/lib/messages/actions/types.d" --> src.lib.messages.actions.service {
        MessageActionInput,
        MessageActionRecord,
        MessageActionResponse,
        MessageActionSkipped,
        MessageStateField,
        MessageStateSnapshot,
        UndoMessageActionResponse,
    }
    "src/lib/security/server-secret" --> src.lib.messages.actions.token { getServerSecret }
    "src/lib/messages/actions/types.d" --> src.lib.messages.actions.token {
        MessageUndoTokenPayload,
    }
    src.db.index --> src.app.api.messages.bulk.route { AppDatabase, getDb }
    src.db.schema.index --> src.app.api.messages.bulk.route { folders, messages }
    src.lib.auth.cookies --> src.app.api.messages.bulk.route { getCurrentUser }
    src.lib.cloudflare --> src.app.api.messages.bulk.route { getEnv }
    src.lib.mailboxes.access --> src.app.api.messages.bulk.route { getMailboxAccessLevel }
    "src/lib/email/draft-access" --> src.app.api.messages.bulk.route { isOthersDraft }
    src.lib.mailboxes.audit --> src.app.api.messages.bulk.route { createAuditLogs }
    "src/lib/email/permanent-delete" --> src.app.api.messages.bulk.route {
        permanentlyDeleteMessages,
    }
    src.lib.spam.feedback --> src.app.api.messages.bulk.route { applySpamFeedback }
    "src/app/api/messages/bulk/types.d" --> src.app.api.messages.bulk.route { BulkMessagePayload }
    src.app.api.messages.bulk.utils --> src.app.api.messages.bulk.route {
        canMoveToFolder,
        getReadValueForBulkAction,
        getStatusForBulkAction,
        isAllowedBulkMessageAction,
        isPermanentlyDeletableStatus,
    }
    src.lib.http.request --> src.app.api.messages.bulk.route { readJsonObject }
    "src/app/api/messages/bulk/types.d" --> src.app.api.messages.bulk.utils {
        BulkMessageAction,
        PermanentDeleteFolder,
    }
    src.db.index --> src.app.api.messages.counts.route { getDb }
    src.db.schema.index --> src.app.api.messages.counts.route { messages }
    src.lib.auth.cookies --> src.app.api.messages.counts.route { getCurrentUser }
    src.lib.cloudflare --> src.app.api.messages.counts.route { getEnv }
    src.lib.email.scheduled --> src.app.api.messages.counts.route { scheduledMessageCondition }
    "src/lib/email/draft-access" --> src.app.api.messages.counts.route { draftsVisibleTo }
    src.app.api.messages.counts.utils --> src.app.api.messages.counts.route {
        activePromotionModes,
        applyPromotionCounts,
        buildMessageCounts,
    }
    src.lib.promotions.settings --> src.app.api.messages.counts.route { loadPromotionModes }
    src.lib.mailboxes.access --> src.app.api.messages.counts.route {
        getMailboxAccessLevel,
        listAccessibleMailboxIds,
    }
    "src/hooks/types.d" --> src.app.api.messages.counts.utils { MessageCounts, MessageFolder }
    src.lib.promotions.settings --> src.app.api.messages.counts.utils { PromotionMode }
    "src/app/api/messages/counts/types.d" --> src.app.api.messages.counts.utils {
        CountableFolder,
        MessageCountRow,
    }
    src.db.index --> src.app.api.messages.empty.route { getDb }
    src.db.schema.index --> src.app.api.messages.empty.route { messages }
    src.lib.auth.cookies --> src.app.api.messages.empty.route { getCurrentUser }
    src.lib.cloudflare --> src.app.api.messages.empty.route { getEnv }
    "src/lib/email/permanent-delete" --> src.app.api.messages.empty.route {
        permanentlyDeleteMessages,
    }
    src.lib.mailboxes.access --> src.app.api.messages.empty.route { getMailboxAccessLevel }
    src.app.api.messages.bulk.utils --> src.app.api.messages.empty.route { isPermanentDeleteFolder }
    "src/app/api/messages/empty/types.d" --> src.app.api.messages.empty.route { EmptyFolderPayload }
    src.app.api.messages.empty.utils --> src.app.api.messages.empty.route {
        EMPTY_FOLDER_BATCH_SIZE,
    }
    src.db.index --> src.app.api.messages.navigation.route { AppDatabase, getDb }
    src.lib.email.scheduled --> src.app.api.messages.navigation.route { scheduledMessageCondition }
    "src/lib/email/draft-access" --> src.app.api.messages.navigation.route { draftsVisibleTo }
    src.db.schema.index --> src.app.api.messages.navigation.route { messages }
    src.lib.auth.cookies --> src.app.api.messages.navigation.route { getCurrentUser }
    src.lib.cloudflare --> src.app.api.messages.navigation.route { getEnv }
    src.lib.promotions.settings --> src.app.api.messages.navigation.route { categoryScopeCondition }
    src.lib.mailboxes.access --> src.app.api.messages.navigation.route {
        getMailboxAccessLevel,
        listAccessibleMailboxIds,
    }
    "src/hooks/types.d" --> src.app.api.messages.navigation.route { MessageFolder }
    "src/app/api/messages/navigation/types.d" --> src.app.api.messages.navigation.route {
        MessageNavigationEntry,
    }
    src.lib.cloudflare --> src.app.api.messages.route { getEnv }
    src.lib.auth.cookies --> src.app.api.messages.route { getCurrentUser }
    src.db.index --> src.app.api.messages.route { getDb }
    src.db.schema.index --> src.app.api.messages.route { messages, outboundJobs }
    src.lib.contacts.service --> src.app.api.messages.route { getContactDisplayNameMap }
    src.lib.contacts.utils --> src.app.api.messages.route { getPartyDisplayName }
    src.lib.email.address --> src.app.api.messages.route {
        getFirstEmailAddressEntry,
        normalizeEmailAddress,
    }
    src.lib.mailboxes.access --> src.app.api.messages.route {
        getMailboxAccessLevel,
        hasMailboxPermission,
        listAccessibleMailboxes,
    }
    "src/lib/profile/identity-utils" --> src.app.api.messages.route { tracksAccountIdentity }
    src.lib.search.conditions --> src.app.api.messages.route { buildSearchConditions }
    src.lib.time.utils --> src.app.api.messages.route { getRequestTimeZone }
    src.lib.email.scheduled --> src.app.api.messages.route { scheduledMessageCondition }
    "src/lib/db-params" --> src.app.api.messages.route { selectInBatches }
    src.app.api.messages.utils --> src.app.api.messages.route {
        getMessageListColumns,
        loadConversationPage,
    }
    "src/app/api/messages/types.d" --> src.app.api.messages.route { ListMessage }
    "src/lib/tracking/open-tracking" --> src.app.api.messages.route { getOpenCounts }
    src.lib.notes.service --> src.app.api.messages.route { summarizeNotesForRows }
    "src/lib/database-errors" --> src.app.api.messages.route { isMissingTableError }
    "src/lib/api/query-params" --> src.app.api.messages.route { parseLimit, parseOffset }
    "src/lib/email/draft-access" --> src.app.api.messages.route { draftsVisibleTo }
    src.lib.promotions.settings --> src.app.api.messages.route { categoryScopeCondition }
    src.db.schema.index --> src.app.api.messages.utils { messages }
    "src/app/api/messages/types.d" --> src.app.api.messages.utils {
        ConversationPage,
        ConversationPageInput,
        MessageListColumns,
    }
    src.lib.cloudflare --> src.app.api.mobile.avatar.route { getEnv }
    src.db.index --> src.app.api.mobile.avatar.route { getDb }
    src.db.schema.index --> src.app.api.mobile.avatar.route { domains, mailboxes, users }
    src.lib.mailboxes.access --> src.app.api.mobile.avatar.route { getMailboxAccessLevel }
    "src/lib/profile/identity-utils" --> src.app.api.mobile.avatar.route { tracksAccountIdentity }
    "src/lib/api/key-auth" --> src.app.api.mobile.avatar.route { authenticateApiRequest, hasScope }
    "src/lib/avatar-images" --> src.app.api.mobile.avatar.route { getAvatarImageResponse }
    src.lib.cloudflare --> src.app.api.mobile.push.route { getEnv }
    "src/lib/api/key-auth" --> src.app.api.mobile.push.route { authenticateApiRequest, hasScope }
    src.lib.http.request --> src.app.api.mobile.push.route { readJsonBody }
    src.lib.push.native --> src.app.api.mobile.push.route {
        canDeliverTo,
        registerPushDevice,
        unregisterPushDevice,
    }
    src.lib.push.relay --> src.app.api.mobile.push.route { isRelayHandle }
    "src/lib/push/native-crypto" --> src.app.api.mobile.push.route { isValidDevicePublicKey }
    src.db.index --> src.app.api.profile.avatar.route { getDb }
    src.lib.auth.cookies --> src.app.api.profile.avatar.route { getCurrentUser }
    src.lib.cloudflare --> src.app.api.profile.avatar.route { getEnv }
    "src/lib/avatar-images" --> src.app.api.profile.avatar.route {
        deleteAvatarImages,
        getAvatarImageResponse,
        getOptimizedAvatarFiles,
        storeAvatarImages,
    }
    src.lib.profile.sync --> src.app.api.profile.avatar.route { syncPersonalIdentity }
    src.app.api.profile.avatar.utils --> src.app.api.profile.avatar.route { avatarKeyFor }
    src.lib.cloudflare --> "src/app/api/provider-events/resend/route" { getEnv }
    "src/lib/deliverability/provider-events" --> "src/app/api/provider-events/resend/route" {
        MAX_EVENT_BYTES,
        processResendEvent,
    }
    src.lib.http.request --> "src/app/api/provider-events/resend/route" { assertRequestSize }
    src.lib.cloudflare --> "src/app/api/provider-events/ses/route" { getEnv }
    "src/lib/deliverability/provider-events" --> "src/app/api/provider-events/ses/route" {
        MAX_EVENT_BYTES,
        processSesFeedback,
    }
    src.lib.http.request --> "src/app/api/provider-events/ses/route" { assertRequestSize }
    src.lib.booking.availability --> "src/app/api/public/booking/[eventId]/route" {
        availableBookingSlots,
    }
    src.lib.cloudflare --> "src/app/api/public/booking/[eventId]/route" { getEnv }
    src.lib.booking.create --> "src/app/api/public/booking/[eventId]/route" {
        createBookedCalendarEvents,
    }
    src.lib.booking.confirmation --> "src/app/api/public/booking/[eventId]/route" {
        sendBookingConfirmation,
    }
    "src/lib/auth/rate-limit" --> "src/app/api/public/booking/[eventId]/route" {
        allowBookingAttempt,
    }
    "src/lib/booking/confirmation-utils" --> "src/app/api/public/booking/[eventId]/route" {
        pickGuestLocale,
    }
    "src/app/api/public/booking/[eventId]/types.d" --> "src/app/api/public/booking/[eventId]/route" {
        PublicBookingRouteContext,
        PublicBookingSubmission,
    }
    "src/app/api/public/booking/[eventId]/utils" --> "src/app/api/public/booking/[eventId]/route" {
        loadPublicBookingEvent,
        parseBookingGuestEmails,
    }
    src.db.index --> src.lib.booking.availability { getDb }
    src.db.schema.index --> src.lib.booking.availability { calendarEventOverrides, calendarEvents }
    src.lib.calendar.chunks --> src.lib.booking.availability { chunkIds }
    src.lib.time.utils --> src.lib.booking.availability { dateFromZonedFields, zonedDateFields }
    src.lib.calendar.recurrence --> src.lib.booking.availability {
        parseCalendarRepeatDays,
        parseExcludedOccurrences,
    }
    src.lib.booking.utils --> src.lib.booking.availability { slotFromLocalDate, timeToMinutes }
    "src/lib/booking/types.d" --> src.lib.booking.availability {
        BookingEventRecord,
        ExistingCalendarEvent,
    }
    src.db.index --> src.lib.booking.confirmation { getDb }
    src.db.schema.index --> src.lib.booking.confirmation { domains, mailboxes, users }
    src.lib.email.send --> src.lib.booking.confirmation { sendEmail }
    src.lib.ids --> src.lib.booking.confirmation { newId }
    "src/lib/profile/identity-utils" --> src.lib.booking.confirmation { mailboxAddress }
    "src/lib/booking/confirmation-utils" --> src.lib.booking.confirmation {
        buildBookingCalendarFile,
        buildBookingConfirmation,
    }
    "src/lib/booking/confirmation-templates" --> src.lib.booking.confirmation {
        getConfirmationTemplates,
    }
    "src/lib/booking/types.d" --> src.lib.booking.confirmation { BookingEventRecord }
    src.db.index --> "src/app/api/public/booking/[eventId]/utils" { getDb }
    src.db.schema.index --> "src/app/api/public/booking/[eventId]/utils" { bookingEvents, users }
    src.lib.booking.utils --> "src/app/api/public/booking/[eventId]/utils" {
        parseBookingTimeRanges,
        parseBookingWeekdays,
    }
    "src/lib/booking/types.d" --> "src/app/api/public/booking/[eventId]/utils" {
        BookingEventRecord,
    }
    src.lib.cloudflare --> "src/app/api/public/booking/[eventId]/utils" { getEnv }
    src.lib.booking.hosts --> "src/app/api/public/booking/[eventId]/utils" { parseBookingHostIds }
    src.db.index --> src.app.api.public.booking.route { getDb }
    src.db.schema.index --> src.app.api.public.booking.route { bookingEvents, users }
    src.lib.cloudflare --> src.app.api.public.booking.route { getEnv }
    src.lib.cloudflare --> src.app.api.push.config.route { getEnv }
    src.lib.api.auth --> src.app.api.push.config.route { requireSessionUser }
    src.lib.push.server --> src.app.api.push.config.route { getVapidPublicKey }
    src.db.index --> src.app.api.push.subscriptions.route { getDb }
    src.db.schema.index --> src.app.api.push.subscriptions.route { pushSubscriptions }
    src.lib.api.auth --> src.app.api.push.subscriptions.route { requireSessionUser }
    src.lib.auth.session --> src.app.api.push.subscriptions.route {
        getSessionFromToken,
        getSessionTokenFromRequestHeaders,
    }
    src.lib.cloudflare --> src.app.api.push.subscriptions.route { getEnv }
    src.lib.ids --> src.app.api.push.subscriptions.route { newId }
    src.lib.push.server --> src.app.api.push.subscriptions.route {
        getVapidPublicKey,
        hasValidPushKeys,
        isSupportedPushEndpoint,
    }
    src.lib.api.auth --> "src/app/api/remote-images/route" { requireSessionUser }
    src.lib.cloudflare --> "src/app/api/remote-images/route" { getEnv }
    "src/lib/remote-images/fetch" --> "src/app/api/remote-images/route" {
        RemoteImageError,
        fetchRemoteImage,
    }
    "src/lib/remote-images/rate-limit" --> "src/app/api/remote-images/route" {
        allowRemoteImageRequest,
    }
    src.db.index --> "src/app/api/routing-rules/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/routing-rules/[id]/route" { routingRules }
    src.lib.auth.cookies --> "src/app/api/routing-rules/[id]/route" { requireUser }
    src.lib.cloudflare --> "src/app/api/routing-rules/[id]/route" { getEnv }
    src.lib.mailboxes.access --> "src/app/api/routing-rules/[id]/route" { getMailboxAccessLevel }
    src.lib.validators --> "src/app/api/routing-rules/[id]/route" { routingRuleSchema }
    "src/app/api/routing-rules/utils" --> "src/app/api/routing-rules/[id]/route" {
        resolveRuleTarget,
    }
    "src/app/api/routing-rules/[id]/types.d" --> "src/app/api/routing-rules/[id]/route" {
        RoutingRuleRouteParams,
    }
    src.lib.http.request --> "src/app/api/routing-rules/[id]/route" { readJsonObject }
    src.lib.auth.session --> "src/app/api/routing-rules/[id]/route" {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.authorize --> "src/app/api/routing-rules/[id]/route" {
        authorizeSecurityChange,
    }
    "src/lib/http/auth-error" --> "src/app/api/routing-rules/[id]/route" { authError }
    "src/lib/routing/forward-proof" --> "src/app/api/routing-rules/[id]/route" {
        forwardTargetChanged,
        isExternalForwardTarget,
    }
    src.db.index --> "src/app/api/routing-rules/utils" { AppDatabase }
    src.db.schema.index --> "src/app/api/routing-rules/utils" { folders }
    src.lib.validators --> "src/app/api/routing-rules/utils" { routingRuleSchema }
    "src/app/api/routing-rules/types.d" --> "src/app/api/routing-rules/utils" { RuleTarget }
    src.db.index --> "src/lib/routing/forward-proof" { AppDatabase }
    src.lib.email.address --> "src/lib/routing/forward-proof" { getEmailAddress }
    src.lib.email.routing --> "src/lib/routing/forward-proof" { resolveInboundAddress }
    src.lib.mailboxes.access --> "src/lib/routing/forward-proof" { listAccessibleMailboxIds }
    "src/lib/auth/types.d" --> "src/lib/routing/forward-proof" { SessionUser }
    src.db.index --> "src/app/api/routing-rules/domain/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/routing-rules/domain/[id]/route" { routingRules }
    src.lib.api.auth --> "src/app/api/routing-rules/domain/[id]/route" { requireSessionUser }
    src.lib.cloudflare --> "src/app/api/routing-rules/domain/[id]/route" { getEnv }
    src.lib.validators --> "src/app/api/routing-rules/domain/[id]/route" { domainRoutingRuleSchema }
    "src/lib/domains/routing-rules" --> "src/app/api/routing-rules/domain/[id]/route" {
        assertAdminRuleMailbox,
        getAdminDomain,
        toRuleColumns,
    }
    "src/app/api/routing-rules/domain/[id]/types.d" --> "src/app/api/routing-rules/domain/[id]/route" {
        DomainRoutingRuleRouteParams,
    }
    src.lib.auth.origin --> "src/app/api/routing-rules/domain/[id]/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.http.request --> "src/app/api/routing-rules/domain/[id]/route" { readJsonObject }
    src.lib.auth.session --> "src/app/api/routing-rules/domain/[id]/route" {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.authorize --> "src/app/api/routing-rules/domain/[id]/route" {
        authorizeSecurityChange,
    }
    "src/lib/http/auth-error" --> "src/app/api/routing-rules/domain/[id]/route" { authError }
    "src/lib/routing/forward-proof" --> "src/app/api/routing-rules/domain/[id]/route" {
        forwardTargetChanged,
        isExternalForwardTarget,
    }
    src.db.index --> "src/lib/domains/routing-rules" { AppDatabase }
    src.db.schema.index --> "src/lib/domains/routing-rules" { domains, mailboxes, routingRules }
    "src/lib/auth/types.d" --> "src/lib/domains/routing-rules" { SessionUser }
    src.lib.mailboxes.access --> "src/lib/domains/routing-rules" {
        getMailboxAccessLevel,
        listAccessibleMailboxes,
    }
    src.lib.auth.admin --> "src/lib/domains/routing-rules" { canManageDomains }
    src.db.index --> "src/app/api/routing-rules/domain/route" { getDb }
    src.db.schema.index --> "src/app/api/routing-rules/domain/route" { routingRules }
    src.lib.api.auth --> "src/app/api/routing-rules/domain/route" { requireSessionUser }
    src.lib.cloudflare --> "src/app/api/routing-rules/domain/route" { getEnv }
    src.lib.ids --> "src/app/api/routing-rules/domain/route" { newId }
    src.lib.validators --> "src/app/api/routing-rules/domain/route" { domainRoutingRuleSchema }
    "src/lib/domains/routing-rules" --> "src/app/api/routing-rules/domain/route" {
        assertAdminRuleMailbox,
        getAdminDomain,
        listAdminDomainMailboxes,
        listAdminRoutingDomains,
        listDomainRules,
        toRuleColumns,
    }
    src.lib.auth.origin --> "src/app/api/routing-rules/domain/route" {
        hasValidSessionMutationOrigin,
    }
    src.lib.http.request --> "src/app/api/routing-rules/domain/route" { readJsonObject }
    src.lib.auth.session --> "src/app/api/routing-rules/domain/route" {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.authorize --> "src/app/api/routing-rules/domain/route" {
        authorizeSecurityChange,
    }
    "src/lib/http/auth-error" --> "src/app/api/routing-rules/domain/route" { authError }
    "src/lib/routing/forward-proof" --> "src/app/api/routing-rules/domain/route" {
        forwardTargetChanged,
        isExternalForwardTarget,
    }
    src.lib.cloudflare --> "src/app/api/routing-rules/route" { getEnv }
    src.db.index --> "src/app/api/routing-rules/route" { getDb }
    src.db.schema.index --> "src/app/api/routing-rules/route" { routingRules }
    src.lib.auth.cookies --> "src/app/api/routing-rules/route" { requireUser }
    src.lib.ids --> "src/app/api/routing-rules/route" { newId }
    src.lib.mailboxes.access --> "src/app/api/routing-rules/route" { getMailboxAccessLevel }
    src.lib.validators --> "src/app/api/routing-rules/route" { routingRuleSchema }
    "src/app/api/routing-rules/utils" --> "src/app/api/routing-rules/route" { resolveRuleTarget }
    src.lib.http.request --> "src/app/api/routing-rules/route" { readJsonObject }
    src.lib.auth.session --> "src/app/api/routing-rules/route" { getSessionTokenFromRequestHeaders }
    src.lib.auth.webauthn.authorize --> "src/app/api/routing-rules/route" {
        authorizeSecurityChange,
    }
    "src/lib/http/auth-error" --> "src/app/api/routing-rules/route" { authError }
    "src/lib/routing/forward-proof" --> "src/app/api/routing-rules/route" {
        forwardTargetChanged,
        isExternalForwardTarget,
    }
    src.db.index --> src.app.api.seed.route { getDb }
    src.db.schema.index --> src.app.api.seed.route { users }
    src.lib.cloudflare --> src.app.api.seed.route { getEnv }
    src.lib.seed --> src.app.api.seed.route { seedDemoData }
    "src/lib/seed-utils" --> src.app.api.seed.route { demoCredentials }
    "src/lib/seed-utils" --> src.lib.seed {
        demoCredentials,
        ensureDemoDomain,
        ensureDemoMailboxes,
        ensureDemoUser,
        insertDemoMessages,
    }
    src.db.index --> "src/lib/seed-utils" { getDb }
    src.db.schema.index --> "src/lib/seed-utils" {
        domains,
        mailboxes,
        messages,
        outboundJobs,
        users,
    }
    src.lib.auth.password --> "src/lib/seed-utils" { hasPasswordHash, hashPassword }
    src.lib.booking.username --> "src/lib/seed-utils" { ensureBookingUsername }
    src.lib.contacts.service --> "src/lib/seed-utils" { upsertContactFromAddress }
    src.lib.email.parse --> "src/lib/seed-utils" { buildSnippet }
    src.lib.ids --> "src/lib/seed-utils" { newId }
    "src/lib/seed-raw" --> "src/lib/seed-utils" { buildSeedRawMessage }
    "src/lib/seed-types.d" --> "src/lib/seed-utils" {
        SeedMailboxKey,
        SeedMailboxMap,
        SeedMessageDefinition,
    }
    src.lib.email.address --> "src/lib/seed-raw" { getEmailAddress }
    "src/lib/seed-types.d" --> "src/lib/seed-raw" { SeedMessageDefinition }
    src.lib.cloudflare --> src.app.api.send.route { getEnv }
    src.lib.auth.cookies --> src.app.api.send.route { requireUser }
    src.lib.validators --> src.app.api.send.route { sendEmailSchema }
    src.lib.email.send --> src.app.api.send.route { sendEmail }
    "src/lib/deliverability/suppression-utils" --> src.app.api.send.route {
        SuppressedRecipientError,
        suppressedRecipientBody,
    }
    src.app.api.send.utils --> src.app.api.send.route { isPastSchedule, parseSendRequest }
    src.lib.http.errors --> src.app.api.send.route { RequestBodyTooLargeError }
    "src/lib/email/attachment-limits" --> src.app.api.send.route { requestBodyLimit }
    "src/lib/email/attachment-policy" --> src.app.api.send.route { getOutboundAttachmentMaxMb }
    "src/app/api/send/error-utils" --> src.app.api.send.route { getSendErrorStatus }
    src.db.index --> src.app.api.send.route { getDb }
    src.db.schema.index --> src.app.api.send.route { agentDraftMetadata, messages }
    src.lib.email.attachments --> src.app.api.send.route { loadMessageAttachmentContents }
    src.app.api.drafts.utils --> src.app.api.send.route { userOwnsDraft }
    src.lib.i18n.server --> src.app.api.send.route { getRequestLocale }
    "src/lib/email/attachment-types.d" --> src.app.api.send.utils { AttachmentContent }
    src.lib.http.request --> src.app.api.send.utils { readFormDataBody, readJsonBody }
    "src/app/api/send/types.d" --> src.app.api.send.utils { SendRequestPayload }
    "src/lib/follow-ups/follow-up-utils" --> src.app.api.send.utils { parseFollowUpDays }
    src.lib.api.auth --> src.app.api.settings.compose.route { requireSessionUser }
    src.lib.cloudflare --> src.app.api.settings.compose.route { getEnv }
    "src/lib/compose/compose-utils" --> src.app.api.settings.compose.route { parseUndoSendSeconds }
    src.lib.compose.preferences --> src.app.api.settings.compose.route {
        ComposePreferencesUnavailableError,
        getComposePreferences,
        updateComposePreferences,
    }
    "src/lib/compose/types.d" --> src.app.api.settings.compose.route { ComposePreferences }
    src.db.index --> src.app.api.settings.forwarding.route { getDb }
    src.db.schema.index --> src.app.api.settings.forwarding.route { users }
    src.lib.auth.cookies --> src.app.api.settings.forwarding.route { requireUser }
    src.lib.auth.origin --> src.app.api.settings.forwarding.route { hasValidSessionMutationOrigin }
    src.lib.auth.session --> src.app.api.settings.forwarding.route {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.grants --> src.app.api.settings.forwarding.route { bumpSecurityVersion }
    src.lib.auth.webauthn.authorize --> src.app.api.settings.forwarding.route {
        authorizeSecurityChange,
    }
    "src/lib/http/auth-error" --> src.app.api.settings.forwarding.route { authError }
    src.lib.cloudflare --> src.app.api.settings.forwarding.route { getEnv }
    src.lib.licenses.service --> src.app.api.settings.forwarding.route { getLicenseEntitlements }
    "src/app/api/settings/forwarding/types.d" --> src.app.api.settings.forwarding.route {
        UpdateForwardingEmailInput,
    }
    src.app.api.settings.forwarding.utils --> src.app.api.settings.forwarding.route {
        parseUpdateForwardingEmailRequest,
    }
    src.lib.validators --> src.app.api.settings.forwarding.utils { updateForwardingEmailSchema }
    "src/app/api/settings/forwarding/types.d" --> src.app.api.settings.forwarding.utils {
        UpdateForwardingEmailInput,
    }
    src.lib.cloudflare --> src.app.api.settings.mfa.confirm.route { getEnv }
    src.lib.api.auth --> src.app.api.settings.mfa.confirm.route { requireSessionUser }
    src.lib.http.request --> src.app.api.settings.mfa.confirm.route { readJsonBody }
    src.db.index --> src.app.api.settings.mfa.confirm.route { getDb }
    src.lib.auth.session --> src.app.api.settings.mfa.confirm.route {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.mfa --> src.app.api.settings.mfa.confirm.route { confirmMfaEnrollment }
    src.lib.validators --> src.app.api.settings.mfa.confirm.route { mfaConfirmSchema }
    src.lib.auth.webauthn.grants --> src.app.api.settings.mfa.confirm.route { bumpSecurityVersion }
    "src/lib/http/auth-error" --> src.app.api.settings.mfa.confirm.route { authError }
    src.lib.cloudflare --> src.app.api.settings.mfa.disable.route { getEnv }
    src.lib.api.auth --> src.app.api.settings.mfa.disable.route { requireSessionUser }
    src.lib.http.request --> src.app.api.settings.mfa.disable.route { readJsonBody }
    src.db.index --> src.app.api.settings.mfa.disable.route { getDb }
    src.lib.auth.mfa --> src.app.api.settings.mfa.disable.route { disableMfa }
    src.lib.validators --> src.app.api.settings.mfa.disable.route { mfaDisableSchema }
    src.lib.auth.session --> src.app.api.settings.mfa.disable.route {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.authorize --> src.app.api.settings.mfa.disable.route {
        authorizeSecurityChange,
    }
    src.lib.auth.webauthn.grants --> src.app.api.settings.mfa.disable.route { bumpSecurityVersion }
    "src/lib/http/auth-error" --> src.app.api.settings.mfa.disable.route { authError }
    src.lib.cloudflare --> src.app.api.settings.mfa.enroll.route { getEnv }
    src.lib.api.auth --> src.app.api.settings.mfa.enroll.route { requireSessionUser }
    src.lib.http.request --> src.app.api.settings.mfa.enroll.route { readJsonBody }
    src.lib.auth.mfa --> src.app.api.settings.mfa.enroll.route { beginMfaEnrollment }
    src.lib.validators --> src.app.api.settings.mfa.enroll.route { mfaEnrollSchema }
    src.lib.auth.session --> src.app.api.settings.mfa.enroll.route {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.authorize --> src.app.api.settings.mfa.enroll.route {
        authorizeSecurityChange,
    }
    "src/lib/http/auth-error" --> src.app.api.settings.mfa.enroll.route { authError }
    src.lib.cloudflare --> "src/app/api/settings/mfa/recovery-codes/route" { getEnv }
    src.lib.api.auth --> "src/app/api/settings/mfa/recovery-codes/route" { requireSessionUser }
    src.lib.http.request --> "src/app/api/settings/mfa/recovery-codes/route" { readJsonBody }
    src.db.index --> "src/app/api/settings/mfa/recovery-codes/route" { getDb }
    "src/lib/auth/recovery-codes" --> "src/app/api/settings/mfa/recovery-codes/route" {
        issueRecoveryCodes,
    }
    src.lib.validators --> "src/app/api/settings/mfa/recovery-codes/route" { mfaEnrollSchema }
    src.lib.auth.session --> "src/app/api/settings/mfa/recovery-codes/route" {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.authorize --> "src/app/api/settings/mfa/recovery-codes/route" {
        authorizeSecurityChange,
    }
    src.lib.auth.webauthn.grants --> "src/app/api/settings/mfa/recovery-codes/route" {
        bumpSecurityVersion,
    }
    "src/lib/http/auth-error" --> "src/app/api/settings/mfa/recovery-codes/route" { authError }
    src.lib.cloudflare --> src.app.api.settings.mfa.route { getEnv }
    src.lib.api.auth --> src.app.api.settings.mfa.route { requireSessionUser }
    src.lib.auth.mfa --> src.app.api.settings.mfa.route { getMfaStatus }
    src.lib.cloudflare --> "src/app/api/settings/passkeys/[id]/route" { getEnv }
    src.lib.api.auth --> "src/app/api/settings/passkeys/[id]/route" { requireSessionUser }
    src.lib.http.request --> "src/app/api/settings/passkeys/[id]/route" { readJsonBody }
    src.lib.validators --> "src/app/api/settings/passkeys/[id]/route" {
        passkeyRenameSchema,
        stepUpTokenSchema,
    }
    src.lib.auth.password --> "src/app/api/settings/passkeys/[id]/route" { hasPasswordHash }
    src.lib.auth.session --> "src/app/api/settings/passkeys/[id]/route" {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.grants --> "src/app/api/settings/passkeys/[id]/route" {
        bumpSecurityVersion,
        consumeStepUpGrant,
    }
    src.lib.auth.webauthn.credentials --> "src/app/api/settings/passkeys/[id]/route" {
        countPasskeys,
        deletePasskey,
        renamePasskey,
    }
    src.lib.auth.activity --> "src/app/api/settings/passkeys/[id]/route" { recordAuthActivity }
    src.db.index --> "src/app/api/settings/passkeys/[id]/route" { getDb }
    "src/lib/http/auth-error" --> "src/app/api/settings/passkeys/[id]/route" {
        authError,
        isLastAuthMethodError,
    }
    src.lib.cloudflare --> src.app.api.settings.passkeys.check.options.route { getEnv }
    src.lib.api.auth --> src.app.api.settings.passkeys.check.options.route { requireSessionUser }
    src.lib.auth.webauthn.credentials --> src.app.api.settings.passkeys.check.options.route {
        listPasskeys,
    }
    src.lib.auth.webauthn.service --> src.app.api.settings.passkeys.check.options.route {
        createAuthenticationOptions,
    }
    src.lib.auth.webauthn.challenges --> src.app.api.settings.passkeys.check.options.route {
        createCeremonyBinding,
        createWebAuthnChallenge,
        readCeremonyBindings,
        setCeremonyCookie,
    }
    src.lib.auth.webauthn.errors --> src.app.api.settings.passkeys.check.options.route {
        webAuthnUnavailableCode,
    }
    "src/lib/http/auth-error" --> src.app.api.settings.passkeys.check.options.route { authError }
    src.lib.cloudflare --> src.app.api.settings.passkeys.check.verify.route { getEnv }
    src.lib.api.auth --> src.app.api.settings.passkeys.check.verify.route { requireSessionUser }
    src.lib.http.request --> src.app.api.settings.passkeys.check.verify.route { readJsonBody }
    src.lib.validators --> src.app.api.settings.passkeys.check.verify.route {
        passkeyCeremonySchema,
    }
    src.lib.auth.webauthn.challenges --> src.app.api.settings.passkeys.check.verify.route {
        consumeWebAuthnChallenge,
        readCeremonyBindings,
        removeCeremonyCookie,
    }
    src.lib.auth.webauthn.service --> src.app.api.settings.passkeys.check.verify.route {
        isAuthenticationResponseJSON,
        verifyPasskeyAuthentication,
    }
    "src/lib/http/auth-error" --> src.app.api.settings.passkeys.check.verify.route { authError }
    src.lib.auth.webauthn.errors --> src.app.api.settings.passkeys.check.verify.route {
        PasskeyVerificationError,
    }
    src.lib.cloudflare --> src.app.api.settings.passkeys.options.route { getEnv }
    src.lib.api.auth --> src.app.api.settings.passkeys.options.route { requireSessionUser }
    src.lib.http.request --> src.app.api.settings.passkeys.options.route { readJsonBody }
    src.lib.validators --> src.app.api.settings.passkeys.options.route { passkeyAddOptionsSchema }
    src.lib.auth.session --> src.app.api.settings.passkeys.options.route {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.credentials --> src.app.api.settings.passkeys.options.route {
        listPasskeys,
    }
    src.lib.auth.webauthn.service --> src.app.api.settings.passkeys.options.route {
        createRegistrationOptions,
    }
    src.lib.auth.webauthn.grants --> src.app.api.settings.passkeys.options.route { peekStepUpGrant }
    src.lib.auth.webauthn.challenges --> src.app.api.settings.passkeys.options.route {
        createCeremonyBinding,
        createWebAuthnChallenge,
        readCeremonyBindings,
        setCeremonyCookie,
    }
    src.lib.auth.webauthn.errors --> src.app.api.settings.passkeys.options.route {
        webAuthnUnavailableCode,
    }
    "src/lib/http/auth-error" --> src.app.api.settings.passkeys.options.route { authError }
    src.lib.cloudflare --> src.app.api.settings.passkeys.route { getEnv }
    src.lib.api.auth --> src.app.api.settings.passkeys.route { requireSessionUser }
    src.lib.http.request --> src.app.api.settings.passkeys.route { readJsonBody }
    src.lib.validators --> src.app.api.settings.passkeys.route { passkeyRegistrationSchema }
    src.lib.auth.session --> src.app.api.settings.passkeys.route {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.grants --> src.app.api.settings.passkeys.route {
        bumpSecurityVersion,
        consumeStepUpGrant,
    }
    src.lib.auth.webauthn.challenges --> src.app.api.settings.passkeys.route {
        consumeWebAuthnChallenge,
        readCeremonyBindings,
        removeCeremonyCookie,
    }
    src.lib.auth.webauthn.service --> src.app.api.settings.passkeys.route {
        isRegistrationResponseJSON,
        verifyPasskeyRegistration,
    }
    src.lib.auth.activity --> src.app.api.settings.passkeys.route { recordAuthActivity }
    src.db.index --> src.app.api.settings.passkeys.route { getDb }
    "src/lib/http/auth-error" --> src.app.api.settings.passkeys.route {
        authError,
        isUniqueCredentialError,
    }
    src.lib.auth.webauthn.errors --> src.app.api.settings.passkeys.route {
        PasskeyVerificationError,
    }
    src.db.index --> src.app.api.settings.password.route { getDb }
    src.db.schema.index --> src.app.api.settings.password.route { users }
    src.lib.auth.cookies --> src.app.api.settings.password.route { requireUser }
    src.lib.auth.session --> src.app.api.settings.password.route {
        deleteUserSessions,
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.password --> src.app.api.settings.password.route {
        PASSWORDLESS_PASSWORD_HASH,
        hasPasswordHash,
        hashPassword,
        verifyPassword,
    }
    src.lib.cloudflare --> src.app.api.settings.password.route { getEnv }
    src.lib.http.request --> src.app.api.settings.password.route { readJsonBody }
    src.lib.validators --> src.app.api.settings.password.route {
        passwordSetSchema,
        stepUpTokenSchema,
    }
    src.lib.auth.webauthn.grants --> src.app.api.settings.password.route {
        bumpSecurityVersion,
        consumeStepUpGrant,
    }
    src.lib.auth.webauthn.credentials --> src.app.api.settings.password.route { countPasskeys }
    src.lib.auth.activity --> src.app.api.settings.password.route { recordAuthActivity }
    "src/lib/http/auth-error" --> src.app.api.settings.password.route {
        authError,
        isLastAuthMethodError,
    }
    "src/app/api/settings/password/types.d" --> src.app.api.settings.password.route {
        ChangePasswordInput,
    }
    src.app.api.settings.password.utils --> src.app.api.settings.password.route {
        parseChangePasswordRequest,
    }
    src.lib.validators --> src.app.api.settings.password.utils { changePasswordSchema }
    "src/app/api/settings/password/types.d" --> src.app.api.settings.password.utils {
        ChangePasswordInput,
    }
    src.lib.cloudflare --> src.app.api.settings.profile.route { getEnv }
    src.db.index --> src.app.api.settings.profile.route { getDb }
    src.db.schema.index --> src.app.api.settings.profile.route { users }
    src.lib.auth.cookies --> src.app.api.settings.profile.route { requireUser }
    src.lib.auth.origin --> src.app.api.settings.profile.route { hasValidSessionMutationOrigin }
    src.lib.auth.session --> src.app.api.settings.profile.route {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.grants --> src.app.api.settings.profile.route { bumpSecurityVersion }
    src.lib.auth.webauthn.authorize --> src.app.api.settings.profile.route {
        authorizeSecurityChange,
    }
    "src/lib/http/auth-error" --> src.app.api.settings.profile.route { authError }
    src.lib.licenses.service --> src.app.api.settings.profile.route { getLicenseEntitlements }
    src.lib.profile.sync --> src.app.api.settings.profile.route { syncPersonalIdentity }
    "src/app/api/settings/profile/types.d" --> src.app.api.settings.profile.route {
        UpdateProfileInput,
    }
    src.app.api.settings.profile.utils --> src.app.api.settings.profile.route {
        parseUpdateProfileRequest,
    }
    src.lib.validators --> src.app.api.settings.profile.utils { updateProfileSchema }
    "src/app/api/settings/profile/types.d" --> src.app.api.settings.profile.utils {
        UpdateProfileInput,
    }
    src.db.index --> "src/app/api/settings/recipient-addresses/route" { getDb }
    src.db.schema.index --> "src/app/api/settings/recipient-addresses/route" { users }
    src.lib.api.auth --> "src/app/api/settings/recipient-addresses/route" { requireSessionUser }
    src.lib.cloudflare --> "src/app/api/settings/recipient-addresses/route" { getEnv }
    "src/app/api/settings/recipient-addresses/types.d" --> "src/app/api/settings/recipient-addresses/route" {
        UpdateRecipientAddressSettingsInput,
    }
    "src/app/api/settings/recipient-addresses/utils" --> "src/app/api/settings/recipient-addresses/route" {
        parseUpdateRecipientAddressSettingsRequest,
    }
    src.lib.validators --> "src/app/api/settings/recipient-addresses/utils" {
        updateRecipientAddressSettingsSchema,
    }
    "src/app/api/settings/recipient-addresses/types.d" --> "src/app/api/settings/recipient-addresses/utils" {
        UpdateRecipientAddressSettingsInput,
    }
    src.db.index --> "src/app/api/settings/remote-content/route" { getDb }
    src.db.schema.index --> "src/app/api/settings/remote-content/route" { contacts, users }
    src.lib.api.auth --> "src/app/api/settings/remote-content/route" { requireSessionUser }
    src.lib.cloudflare --> "src/app/api/settings/remote-content/route" { getEnv }
    src.lib.contacts.utils --> "src/app/api/settings/remote-content/route" { getContactId }
    src.lib.validators --> "src/app/api/settings/remote-content/route" {
        trustRemoteContentSenderSchema,
        updateRemoteContentSettingsSchema,
    }
    src.db.index --> "src/app/api/settings/second-factor/route" { getDb }
    src.db.schema.index --> "src/app/api/settings/second-factor/route" { users }
    src.lib.cloudflare --> "src/app/api/settings/second-factor/route" { getEnv }
    src.lib.api.auth --> "src/app/api/settings/second-factor/route" { requireSessionUser }
    src.lib.http.request --> "src/app/api/settings/second-factor/route" { readJsonBody }
    src.lib.validators --> "src/app/api/settings/second-factor/route" { requireSecondFactorSchema }
    src.lib.auth.session --> "src/app/api/settings/second-factor/route" {
        getSessionTokenFromRequestHeaders,
    }
    src.lib.auth.webauthn.grants --> "src/app/api/settings/second-factor/route" {
        bumpSecurityVersion,
        consumeStepUpGrant,
    }
    "src/lib/http/auth-error" --> "src/app/api/settings/second-factor/route" { authError }
    src.lib.cloudflare --> src.app.api.settings.security.route { getEnv }
    src.lib.api.auth --> src.app.api.settings.security.route { requireSessionUser }
    src.lib.auth.password --> src.app.api.settings.security.route { hasPasswordHash }
    "src/lib/auth/recovery-codes" --> src.app.api.settings.security.route {
        countUnusedRecoveryCodes,
    }
    src.lib.auth.webauthn.credentials --> src.app.api.settings.security.route { listPasskeys }
    src.db.index --> src.app.api.settings.shortcuts.route { getDb }
    src.db.schema.index --> src.app.api.settings.shortcuts.route { users }
    src.lib.api.auth --> src.app.api.settings.shortcuts.route { requireSessionUser }
    src.lib.cloudflare --> src.app.api.settings.shortcuts.route { getEnv }
    "src/app/api/settings/shortcuts/types.d" --> src.app.api.settings.shortcuts.route {
        UpdateShortcutsSettingsInput,
    }
    src.app.api.settings.shortcuts.utils --> src.app.api.settings.shortcuts.route {
        parseUpdateShortcutsSettingsRequest,
    }
    src.lib.validators --> src.app.api.settings.shortcuts.utils { updateShortcutsSettingsSchema }
    "src/app/api/settings/shortcuts/types.d" --> src.app.api.settings.shortcuts.utils {
        UpdateShortcutsSettingsInput,
    }
    src.db.index --> src.app.api.settings.spam.route { getDb }
    src.db.schema.index --> src.app.api.settings.spam.route { users }
    src.lib.api.auth --> src.app.api.settings.spam.route { requireSessionUser }
    src.lib.cloudflare --> src.app.api.settings.spam.route { getEnv }
    "src/app/api/settings/spam/types.d" --> src.app.api.settings.spam.route {
        UpdateSpamSettingsInput,
    }
    src.app.api.settings.spam.utils --> src.app.api.settings.spam.route {
        parseUpdateSpamSettingsRequest,
    }
    src.lib.validators --> src.app.api.settings.spam.utils { updateSpamSettingsSchema }
    "src/app/api/settings/spam/types.d" --> src.app.api.settings.spam.utils {
        UpdateSpamSettingsInput,
    }
    src.db.index --> "src/app/api/settings/time-zone/route" { getDb }
    src.db.schema.index --> "src/app/api/settings/time-zone/route" { calendarEvents, users }
    src.lib.auth.cookies --> "src/app/api/settings/time-zone/route" { getCurrentUser }
    src.lib.cloudflare --> "src/app/api/settings/time-zone/route" { getEnv }
    src.lib.auth.origin --> "src/app/api/settings/time-zone/route" { hasValidSessionMutationOrigin }
    "src/app/api/settings/time-zone/utils" --> "src/app/api/settings/time-zone/route" {
        parseTimeZoneUpdate,
    }
    src.lib.time.utils --> "src/app/api/settings/time-zone/route" { getRequestTimeZone }
    src.lib.time.utils --> "src/app/api/settings/time-zone/utils" {
        isValidTimeZone,
        normalizeTimeZone,
    }
    "src/app/api/settings/time-zone/types.d" --> "src/app/api/settings/time-zone/utils" {
        UpdateTimeZoneInput,
    }
    src.db.index --> "src/app/api/settings/trash-retention/route" { getDb }
    src.db.schema.index --> "src/app/api/settings/trash-retention/route" { users }
    src.lib.api.auth --> "src/app/api/settings/trash-retention/route" { requireSessionUser }
    src.lib.cloudflare --> "src/app/api/settings/trash-retention/route" { getEnv }
    "src/lib/email/trash-retention-utils" --> "src/app/api/settings/trash-retention/route" {
        normalizeTrashRetentionDays,
    }
    "src/app/api/settings/trash-retention/types.d" --> "src/app/api/settings/trash-retention/route" {
        UpdateTrashRetentionSettingsInput,
    }
    "src/app/api/settings/trash-retention/utils" --> "src/app/api/settings/trash-retention/route" {
        parseUpdateTrashRetentionSettingsRequest,
    }
    src.lib.validators --> "src/app/api/settings/trash-retention/utils" {
        updateTrashRetentionSettingsSchema,
    }
    "src/app/api/settings/trash-retention/types.d" --> "src/app/api/settings/trash-retention/utils" {
        UpdateTrashRetentionSettingsInput,
    }
    src.lib.auth.setup --> src.app.api.setup.domain.mx.route { hasAdminAccount }
    src.lib.cloudflare --> src.app.api.setup.domain.mx.route { getEnv }
    src.lib.domains.preflight --> src.app.api.setup.domain.mx.route { preflightSetupDomain }
    src.lib.domains.provision --> src.app.api.setup.domain.mx.route { isManualZone }
    "src/lib/domains/mx-records" --> src.app.api.setup.domain.mx.route { hasConflictingMxRecords }
    src.lib.validators --> src.app.api.setup.domain.mx.route { setupDomainSchema }
    src.lib.http.request --> src.app.api.setup.domain.mx.route { readJsonBody }
    src.lib.http.errors --> src.app.api.setup.domain.mx.route { RequestBodyTooLargeError }
    src.lib.auth.setup --> src.app.api.setup.domain.route { hasAdminAccount }
    src.lib.cloudflare --> src.app.api.setup.domain.route { getEnv }
    src.lib.domains.preflight --> src.app.api.setup.domain.route { preflightSetupDomain }
    src.lib.user --> src.app.api.setup.domain.route { getPrimaryDomain }
    src.lib.validators --> src.app.api.setup.domain.route { setupDomainSchema }
    src.lib.http.request --> src.app.api.setup.domain.route { readJsonBody }
    src.lib.http.errors --> src.app.api.setup.domain.route { RequestBodyTooLargeError }
    src.lib.auth.setup --> src.app.api.setup.prepare.route { hasAdminAccount }
    src.lib.cloudflare --> src.app.api.setup.prepare.route { getEnv }
    src.lib.setup.configuration --> src.app.api.setup.prepare.route { getSetupRequirementChecks }
    src.lib.setup.migration --> src.app.api.setup.prepare.route { migrateCleanDatabase }
    "src/db/with-database" --> src.lib.setup.configuration { getDatabaseConfig }
    src.lib.runtime --> src.lib.setup.configuration { hasCloudflareCredentials, isNodeRuntime }
    "src/lib/setup/types.d" --> src.lib.setup.configuration { SetupRequirementCheck }
    src.lib.migrations.service --> src.lib.setup.migration { applyPendingMigrations }
    src.lib.auth.setup --> src.app.api.setup.status.route { hasAdminAccount }
    src.lib.cloudflare --> src.app.api.setup.status.route { getEnv }
    src.lib.user --> src.app.api.setup.status.route { getPrimaryDomain }
    src.db.index --> "src/app/api/shared-files/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/shared-files/[id]/route" {
        mailboxes,
        messageAttachments,
        messages,
        sharedAttachmentLinks,
    }
    src.lib.cloudflare --> "src/app/api/shared-files/[id]/route" { getEnv }
    "src/app/api/messages/[messageId]/attachments/[attachmentId]/utils" --> "src/app/api/shared-files/[id]/route" {
        getAttachmentContentDisposition,
    }
    "src/app/api/shared-files/[id]/types.d" --> "src/app/api/shared-files/[id]/route" {
        SharedFileParams,
    }
    src.db.index --> src.app.api.subscriptions.preference.route { getDb }
    src.lib.cloudflare --> src.app.api.subscriptions.preference.route { getEnv }
    src.lib.promotions.refile --> src.app.api.subscriptions.preference.route {
        refileSenderMessages,
        setSenderOverride,
    }
    "src/lib/promotions/refile-utils" --> src.app.api.subscriptions.preference.route {
        parsePreferenceBody,
        targetOf,
    }
    "src/lib/promotions/route-guards" --> src.app.api.subscriptions.preference.route {
        MIGRATION_REQUIRED,
        authorizeMutation,
        checkManagedMailbox,
        isMissingSchema,
    }
    src.db.index --> src.app.api.subscriptions.route { getDb }
    src.lib.auth.cookies --> src.app.api.subscriptions.route { getCurrentUser }
    "src/lib/api/query-params" --> src.app.api.subscriptions.route { parseLimit, parseOffset }
    src.lib.cloudflare --> src.app.api.subscriptions.route { getEnv }
    "src/lib/database-errors" --> src.app.api.subscriptions.route { isMissingTableError }
    src.lib.mailboxes.access --> src.app.api.subscriptions.route { getMailboxAccessLevel }
    src.lib.promotions.settings --> src.app.api.subscriptions.route { loadPromotionModes }
    src.lib.promotions.subscriptions --> src.app.api.subscriptions.route { listSubscriptions }
    "src/lib/promotions/subscriptions-utils" --> src.app.api.subscriptions.route {
        SUBSCRIPTIONS_PAGE_SIZE,
    }
    src.db.index --> src.app.api.subscriptions.trash.route { getDb }
    src.lib.cloudflare --> src.app.api.subscriptions.trash.route { getEnv }
    src.lib.mailboxes.audit --> src.app.api.subscriptions.trash.route { createAuditLog }
    src.lib.promotions.subscriptions --> src.app.api.subscriptions.trash.route {
        previewSenderTrash,
        trashSenderMessages,
    }
    "src/lib/promotions/subscriptions-utils" --> src.app.api.subscriptions.trash.route {
        parseTrashBody,
    }
    "src/lib/promotions/route-guards" --> src.app.api.subscriptions.trash.route {
        MIGRATION_REQUIRED,
        authorizeMutation,
        checkManagedMailbox,
        isMissingSchema,
    }
    src.db.index --> "src/app/api/templates/[id]/route" { getDb }
    src.db.schema.index --> "src/app/api/templates/[id]/route" { messages }
    src.lib.api.auth --> "src/app/api/templates/[id]/route" { requireSessionUser }
    src.lib.auth.origin --> "src/app/api/templates/[id]/route" { hasValidSessionMutationOrigin }
    src.lib.cloudflare --> "src/app/api/templates/[id]/route" { getEnv }
    "src/lib/email/message-cleanup" --> "src/app/api/templates/[id]/route" {
        deleteMessageWithObjects,
    }
    src.db.index --> src.app.api.templates.route { getDb }
    src.db.schema.index --> src.app.api.templates.route { messages }
    src.lib.api.auth --> src.app.api.templates.route { requireSessionUser }
    src.lib.auth.origin --> src.app.api.templates.route { hasValidSessionMutationOrigin }
    src.lib.cloudflare --> src.app.api.templates.route { getEnv }
    src.lib.ids --> src.app.api.templates.route { newId }
    src.lib.email.parse --> src.app.api.templates.route { buildSnippet }
    src.app.api.drafts.utils --> src.app.api.templates.route { getDraftSender }
    "src/app/api/v1/accounts/[id]/utils" --> "src/app/api/v1/accounts/[id]/route" { GET, PATCH }
    src.lib.cloudflare --> "src/app/api/v1/accounts/[id]/utils" { getEnv }
    src.db.index --> "src/app/api/v1/accounts/[id]/utils" { getDb }
    src.db.schema.index --> "src/app/api/v1/accounts/[id]/utils" { users }
    "src/lib/api/admin-auth" --> "src/app/api/v1/accounts/[id]/utils" {
        authenticateAdminApiKey,
        canManageAdminAccounts,
    }
    src.lib.auth.admin --> "src/app/api/v1/accounts/[id]/utils" { isPrimaryAdmin }
    src.lib.validators --> "src/app/api/v1/accounts/[id]/utils" { updateManagedAccountSchema }
    src.lib.licenses.service --> "src/app/api/v1/accounts/[id]/utils" { getLicenseEntitlements }
    "src/app/api/accounts/[id]/utils" --> "src/app/api/v1/accounts/[id]/utils" {
        AccountSecurityChangedError,
        PasskeyOnlyPasswordError,
        selectAccountById,
        updateAccountCredentials,
    }
    src.lib.auth.session --> "src/app/api/v1/accounts/[id]/utils" { deleteUserSessions }
    src.lib.mailboxes.audit --> "src/app/api/v1/accounts/[id]/utils" { createAuditLog }
    "src/app/api/v1/accounts/[id]/types.d" --> "src/app/api/v1/accounts/[id]/utils" {
        AdminAccountRouteParams,
    }
    src.lib.api.auth --> "src/lib/api/admin-auth" { authenticateApiKey }
    "src/lib/api/key-auth-types.d" --> "src/lib/api/admin-auth" { ApiAuthResult }
    "src/lib/api/scopes-types.d" --> "src/lib/api/admin-auth" { AdminApiKeyScope }
    src.lib.licenses.service --> "src/lib/api/admin-auth" { getLicenseEntitlements }
    src.app.api.v1.accounts.utils --> src.app.api.v1.accounts.route { GET, POST }
    src.lib.cloudflare --> src.app.api.v1.accounts.utils { getEnv }
    src.db.index --> src.app.api.v1.accounts.utils { getDb }
    src.db.schema.index --> src.app.api.v1.accounts.utils { users }
    "src/lib/api/admin-auth" --> src.app.api.v1.accounts.utils {
        authenticateAdminApiKey,
        canManageAdminAccounts,
    }
    src.lib.auth.admin --> src.app.api.v1.accounts.utils { isPrimaryAdmin }
    src.lib.validators --> src.app.api.v1.accounts.utils { createUserAccountSchema }
    src.app.api.accounts.utils --> src.app.api.v1.accounts.utils { accountListItemFromUser }
    src.app.api.accounts.create --> src.app.api.v1.accounts.utils { createAccountResponse }
    src.lib.cloudflare --> "src/app/api/v1/domains/[id]/dns/route" { getEnv }
    "src/lib/api/admin-auth" --> "src/app/api/v1/domains/[id]/dns/route" { authenticateAdminApiKey }
    src.lib.domains.service --> "src/app/api/v1/domains/[id]/dns/route" { getDomainForUser }
    "src/lib/domains/dns-view" --> "src/app/api/v1/domains/[id]/dns/route" { getDomainDnsView }
    src.lib.cloudflare --> "src/app/api/v1/domains/[id]/dns/setup/route" { getEnv }
    src.db.index --> "src/app/api/v1/domains/[id]/dns/setup/route" { getDb }
    src.db.schema.index --> "src/app/api/v1/domains/[id]/dns/setup/route" { domains }
    "src/lib/api/admin-auth" --> "src/app/api/v1/domains/[id]/dns/setup/route" {
        authenticateAdminApiKey,
    }
    src.lib.domains.service --> "src/app/api/v1/domains/[id]/dns/setup/route" { getDomainForUser }
    "src/lib/domains/dns-view" --> "src/app/api/v1/domains/[id]/dns/setup/route" {
        getDomainDnsView,
    }
    "src/lib/domains/dns-audit" --> "src/app/api/v1/domains/[id]/dns/setup/route" { DnsAuthRecord }
    "src/lib/domains/dns-setup" --> "src/app/api/v1/domains/[id]/dns/setup/route" {
        setupDomainDnsRecord,
    }
    "src/lib/domains/receiving-dns" --> "src/app/api/v1/domains/[id]/dns/setup/route" {
        MxConflictError,
    }
    "src/lib/deliverability/mta-sts-block-response" --> "src/app/api/v1/domains/[id]/dns/setup/route" {
        mtaStsBlockedResponse,
    }
    src.lib.cloudflare --> "src/app/api/v1/domains/[id]/route" { getEnv }
    "src/lib/api/admin-auth" --> "src/app/api/v1/domains/[id]/route" { authenticateAdminApiKey }
    src.lib.domains.service --> "src/app/api/v1/domains/[id]/route" {
        getDomainForUser,
        removeDomainForUser,
    }
    "src/lib/deliverability/mta-sts-block-response" --> "src/app/api/v1/domains/[id]/route" {
        mtaStsBlockedResponse,
    }
    src.lib.cloudflare --> src.app.api.v1.domains.route { getEnv }
    "src/lib/api/admin-auth" --> src.app.api.v1.domains.route { authenticateAdminApiKey }
    src.lib.validators --> src.app.api.v1.domains.route { addDomainSchema }
    src.lib.domains.service --> src.app.api.v1.domains.route { addDomainForUser, listUserDomains }
    src.lib.domains.utils --> src.app.api.v1.domains.route { domainListOwnerIds }
    "src/lib/domains/dns-view" --> src.app.api.v1.domains.route {
        getDomainDnsView,
        summariseDomainDns,
    }
    src.lib.domains.errors --> src.app.api.v1.domains.route { getDomainProvisioningError }
    "src/lib/deliverability/mta-sts-block-response" --> src.app.api.v1.domains.route {
        mtaStsBlockedResponse,
    }
    "src/lib/dns-status" --> src.app.api.v1.domains.route { DnsStatusSummary }
    "src/app/api/v1/mailboxes/[id]/utils" --> "src/app/api/v1/mailboxes/[id]/route" {
        DELETE,
        GET,
        PATCH,
    }
    src.lib.cloudflare --> "src/app/api/v1/mailboxes/[id]/utils" { getEnv }
    src.db.index --> "src/app/api/v1/mailboxes/[id]/utils" { getDb }
    src.db.schema.index --> "src/app/api/v1/mailboxes/[id]/utils" { mailboxes, users }
    "src/lib/api/admin-auth" --> "src/app/api/v1/mailboxes/[id]/utils" { authenticateAdminApiKey }
    src.lib.validators --> "src/app/api/v1/mailboxes/[id]/utils" { updateMailboxSchema }
    "src/app/api/mailboxes/[id]/utils" --> "src/app/api/v1/mailboxes/[id]/utils" {
        getMailboxUpdateValues,
    }
    "src/lib/mailboxes/domain-addresses" --> "src/app/api/v1/mailboxes/[id]/utils" {
        ensureMailboxDomainRouting,
        removeMailboxDomainRouting,
    }
    "src/app/api/v1/mailboxes/[id]/types.d" --> "src/app/api/v1/mailboxes/[id]/utils" {
        AdminMailboxRouteParams,
    }
    src.app.api.v1.mailboxes.utils --> src.app.api.v1.mailboxes.route { GET, POST }
    "src/lib/deliverability/report-address" --> src.app.api.v1.mailboxes.utils {
        isReportAddressReserved,
    }
    src.lib.cloudflare --> src.app.api.v1.mailboxes.utils { getEnv }
    src.db.index --> src.app.api.v1.mailboxes.utils { getDb }
    src.db.schema.index --> src.app.api.v1.mailboxes.utils {
        domains,
        mailboxAliases,
        mailboxes,
        users,
    }
    "src/lib/api/admin-auth" --> src.app.api.v1.mailboxes.utils {
        authenticateAdminApiKey,
        canShareAdminMailboxes,
    }
    src.lib.ids --> src.app.api.v1.mailboxes.utils { newId }
    src.lib.validators --> src.app.api.v1.mailboxes.utils { mailboxSchema }
    "src/lib/mailboxes/domain-addresses" --> src.app.api.v1.mailboxes.utils {
        ensureMailboxDomainRouting,
    }
    "src/lib/email/recipient-address" --> src.app.api.v1.mailboxes.utils {
        normalizeRecipientLocalPart,
    }
    src.lib.cloudflare --> src.app.api.v1.messages.route { getEnv }
    src.lib.api.auth --> src.app.api.v1.messages.route { authenticateApiKey, requireScope }
    src.db.index --> src.app.api.v1.messages.route { getDb }
    src.db.schema.index --> src.app.api.v1.messages.route { messages, users }
    src.lib.mailboxes.access --> src.app.api.v1.messages.route {
        getMailboxAccessLevel,
        listAccessibleMailboxIds,
    }
    src.lib.search.conditions --> src.app.api.v1.messages.route { buildSearchConditions }
    "src/lib/email/draft-access" --> src.app.api.v1.messages.route { draftsVisibleTo }
    src.lib.time.utils --> src.app.api.v1.messages.route { getRequestTimeZone }
    "src/lib/api/query-params" --> src.app.api.v1.messages.route { parseLimit }
    src.lib.cloudflare --> src.app.api.v1.send.route { getEnv }
    src.lib.api.auth --> src.app.api.v1.send.route { authenticateApiKey, requireScope }
    src.lib.validators --> src.app.api.v1.send.route { sendEmailSchema }
    src.lib.email.send --> src.app.api.v1.send.route { sendEmail }
    "src/lib/deliverability/suppression-utils" --> src.app.api.v1.send.route {
        SuppressedRecipientError,
        suppressedRecipientBody,
    }
    src.lib.email.attachments --> src.app.api.v1.send.route { decodeBase64Content }
    src.lib.http.request --> src.app.api.v1.send.route { readJsonBody }
    src.lib.http.errors --> src.app.api.v1.send.route { RequestBodyTooLargeError }
    "src/app/api/send/error-utils" --> src.app.api.v1.send.route { getSendErrorStatus }
    src.lib.cloudflare --> src.app.api.v1.storage.route { getEnv }
    "src/lib/api/admin-auth" --> src.app.api.v1.storage.route { authenticateAdminApiKey }
    "src/lib/storage/b2-config" --> src.app.api.v1.storage.route {
        describeB2Problem,
        getStorageStatus,
    }
    src.lib.storage.health --> src.app.api.v1.storage.route { testStorage }
    src.lib.ids --> src.lib.storage.health { newId }
    src.lib.email.webhooks --> "src/app/api/webhooks/[id]/deliveries/[deliveryId]/retry/route" {
        runDelivery,
    }
    "src/app/api/webhooks/[id]/utils" --> "src/app/api/webhooks/[id]/deliveries/[deliveryId]/retry/route" {
        loadOwnedWebhook,
    }
    "src/app/api/webhooks/[id]/types.d" --> "src/app/api/webhooks/[id]/deliveries/[deliveryId]/retry/route" {
        WebhookDeliveryRouteParams,
    }
    src.db.index --> "src/app/api/webhooks/[id]/utils" { getDb }
    src.db.schema.index --> "src/app/api/webhooks/[id]/utils" { webhooks }
    src.lib.api.auth --> "src/app/api/webhooks/[id]/utils" { requireSessionUser }
    src.lib.auth.admin --> "src/app/api/webhooks/[id]/utils" { isPrimaryAdmin }
    src.lib.cloudflare --> "src/app/api/webhooks/[id]/utils" { getEnv }
    src.db.schema.index --> "src/app/api/webhooks/[id]/deliveries/route" { webhookDeliveries }
    "src/app/api/webhooks/[id]/utils" --> "src/app/api/webhooks/[id]/deliveries/route" {
        loadOwnedWebhook,
    }
    "src/app/api/webhooks/[id]/types.d" --> "src/app/api/webhooks/[id]/deliveries/route" {
        WebhookRouteParams,
    }
    "src/lib/api/query-params" --> "src/app/api/webhooks/[id]/deliveries/route" { parseLimit }
    src.db.schema.index --> "src/app/api/webhooks/[id]/route" { webhooks }
    src.lib.email.webhooks --> "src/app/api/webhooks/[id]/route" { parseWebhookEvents }
    src.lib.validators --> "src/app/api/webhooks/[id]/route" { webhookUpdateSchema }
    "src/app/api/webhooks/[id]/utils" --> "src/app/api/webhooks/[id]/route" { loadOwnedWebhook }
    "src/app/api/webhooks/[id]/types.d" --> "src/app/api/webhooks/[id]/route" { WebhookRouteParams }
    src.lib.ids --> "src/app/api/webhooks/[id]/route" { newId }
    src.lib.auth.origin --> "src/app/api/webhooks/[id]/route" { hasValidSessionMutationOrigin }
    src.lib.http.request --> "src/app/api/webhooks/[id]/route" { readJsonObject }
    src.lib.auth.session --> "src/app/api/webhooks/[id]/route" { getSessionTokenFromRequestHeaders }
    src.lib.auth.webauthn.authorize --> "src/app/api/webhooks/[id]/route" {
        authorizeSecurityChange,
    }
    "src/lib/http/auth-error" --> "src/app/api/webhooks/[id]/route" { authError }
    src.lib.email.webhooks --> "src/app/api/webhooks/[id]/test/route" { sendTestDelivery }
    "src/app/api/webhooks/[id]/utils" --> "src/app/api/webhooks/[id]/test/route" {
        loadOwnedWebhook,
    }
    "src/app/api/webhooks/[id]/types.d" --> "src/app/api/webhooks/[id]/test/route" {
        WebhookRouteParams,
    }
    src.lib.cloudflare --> src.app.api.webhooks.route { getEnv }
    src.db.index --> src.app.api.webhooks.route { getDb }
    src.db.schema.index --> src.app.api.webhooks.route { webhookDeliveries, webhooks }
    src.lib.email.webhooks --> src.app.api.webhooks.route { parseWebhookEvents }
    src.app.api.webhooks.utils --> src.app.api.webhooks.route { summariseDeliveryStats }
    src.lib.api.auth --> src.app.api.webhooks.route { requireSessionUser }
    src.lib.auth.admin --> src.app.api.webhooks.route { isPrimaryAdmin }
    src.lib.ids --> src.app.api.webhooks.route { newId }
    src.lib.validators --> src.app.api.webhooks.route { webhookSchema }
    src.lib.http.request --> src.app.api.webhooks.route { readJsonBody }
    src.lib.http.errors --> src.app.api.webhooks.route { RequestBodyTooLargeError }
    src.lib.auth.origin --> src.app.api.webhooks.route { hasValidSessionMutationOrigin }
    src.lib.auth.session --> src.app.api.webhooks.route { getSessionTokenFromRequestHeaders }
    src.lib.auth.webauthn.authorize --> src.app.api.webhooks.route { authorizeSecurityChange }
    "src/lib/http/auth-error" --> src.app.api.webhooks.route { authError }
    "src/components/language-provider" --> "src/app/book/[userId]/[eventId]/booking-detail-skeleton" {
        useLanguage,
    }
    src.components.icons --> "src/app/book/[userId]/[eventId]/page" {
        ArrowLeft,
        CalendarDays,
        Check,
        ChevronLeft,
        ChevronRight,
        Clock3,
        Globe2,
        MapPin,
        Users,
    }
    "src/components/language-provider" --> "src/app/book/[userId]/[eventId]/page" { useLanguage }
    "src/components/language-selector" --> "src/app/book/[userId]/[eventId]/page" {
        LanguageSelector,
    }
    src.components.ui.button --> "src/app/book/[userId]/[eventId]/page" { Button }
    src.components.ui.input --> "src/app/book/[userId]/[eventId]/page" { Input }
    src.components.ui.textarea --> "src/app/book/[userId]/[eventId]/page" { Textarea }
    "src/components/branding-provider" --> "src/app/book/[userId]/[eventId]/page" { useBranding }
    "src/components/route-loading-bar" --> "src/app/book/[userId]/[eventId]/page" {
        RouteLoadingBar,
    }
    src.lib.time.utils --> "src/app/book/[userId]/[eventId]/page" {
        formatUserDate,
        getUserTimeZone,
    }
    "src/app/book/[userId]/types.d" --> "src/app/book/[userId]/[eventId]/page" {
        BookingSlot,
        PublicBookingEvent,
    }
    "src/app/book/[userId]/[eventId]/utils" --> "src/app/book/[userId]/[eventId]/page" {
        bookingTimeZones,
        calendarDays,
        formatCalendarDate,
        localDateForSlot,
        moveMonth,
        readBookingPageSelection,
        submitPublicBooking,
        writeBookingPageSelection,
    }
    "src/app/book/[userId]/[eventId]/booking-detail-skeleton" --> "src/app/book/[userId]/[eventId]/page" {
        BookingDetailSkeleton,
    }
    src.components.ui.select --> "src/app/book/[userId]/[eventId]/page" { Select }
    src.lib.time.utils --> "src/app/book/[userId]/[eventId]/utils" {
        getDisplayLocale,
        isValidTimeZone,
    }
    src.lib.i18n.utils --> "src/app/book/[userId]/[eventId]/utils" { defaultTranslator }
    "src/app/book/[userId]/types.d" --> "src/app/book/[userId]/[eventId]/utils" { BookingSlot }
    "src/app/book/[userId]/[eventId]/types.d" --> "src/app/book/[userId]/[eventId]/utils" {
        BookingPageSelection,
    }
    "src/components/language-provider" --> "src/app/book/[userId]/booking-list-skeleton" {
        useLanguage,
    }
    src.components.icons --> "src/app/book/[userId]/page" { ArrowRight, Clock3, MapPin }
    "src/components/language-provider" --> "src/app/book/[userId]/page" { useLanguage }
    "src/components/language-selector" --> "src/app/book/[userId]/page" { LanguageSelector }
    "src/components/branding-provider" --> "src/app/book/[userId]/page" { useBranding }
    "src/components/route-loading-bar" --> "src/app/book/[userId]/page" { RouteLoadingBar }
    "src/app/book/[userId]/types.d" --> "src/app/book/[userId]/page" { PublicBookingEvent }
    "src/app/book/[userId]/booking-list-skeleton" --> "src/app/book/[userId]/page" {
        BookingListSkeleton,
    }
    "src/app/book/[userId]/[eventId]/page" --> "src/app/c/[username]/[slug]/page" { default }
    "src/app/book/[userId]/page" --> "src/app/c/[username]/page" { default }
    src.components.icons --> "src/app/d/[token]/page" { ChevronRight, Download }
    "src/components/language-provider" --> "src/app/d/[token]/page" { useLanguage }
    src.lib.drive.utils --> "src/app/d/[token]/page" { formatDriveSize }
    "src/app/(drive)/drive-preview" --> "src/app/d/[token]/page" { DrivePreviewBody }
    "src/app/(drive)/drive-utils" --> "src/app/d/[token]/page" {
        driveIconFor,
        publicContentUrl,
        sortDriveItems,
    }
    "src/app/d/[token]/types.d" --> "src/app/d/[token]/page" { PublicDriveItem, PublicDriveListing }
    "src/components/mailbox-provider" --> "src/app/home-account-menu" { MailboxProvider }
    "src/components/mailbox-selector" --> "src/app/home-account-menu" { MailboxSelector }
    "src/app/types.d" --> "src/app/home-account-menu" { HomeAccountMenuProps }
    src.lib.auth.client --> "src/app/home-auth" {
        AUTH_SESSION_CHANGED_EVENT,
        getClientSessionToken,
    }
    "src/hooks/use-current-user" --> "src/app/home-auth" { clearCurrentUserCache, fetchCurrentUser }
    "src/components/mailbox-selector-types.d" --> "src/app/home-auth" { MailboxSelectorUser }
    "src/app/types.d" --> "src/app/home-auth" { HomeAuthProviderProps }
    "src/components/language-provider" --> "src/app/home-header-actions" { useLanguage }
    "src/components/language-selector" --> "src/app/home-header-actions" { LanguageSelector }
    src.components.ui.button --> "src/app/home-header-actions" { Button }
    src.app.utils --> "src/app/home-header-actions" { getHomeActions }
    "src/app/home-account-menu" --> "src/app/home-header-actions" { HomeAccountMenu }
    "src/app/home-auth" --> "src/app/home-header-actions" { useHomeAuth }
    src.components.icons --> src.app.utils { FileText, Inbox, MailCheck, Send, ShieldAlert, Trash2 }
    "src/app/types.d" --> src.app.utils {
        HomeAction,
        LandingNavItem,
        LandingStat,
        MailPreview,
        SidebarItem,
    }
    src.components.icons --> "src/app/home-hero-actions" { ArrowRight }
    "src/components/language-provider" --> "src/app/home-hero-actions" { useLanguage }
    src.components.ui.button --> "src/app/home-hero-actions" { Button }
    "src/app/home-auth" --> "src/app/home-hero-actions" { useHomeAuth }
    src.components.providers --> src.app.layout { Providers }
    "src/components/language-provider" --> src.app.layout { LanguageProvider }
    src.lib.i18n.utils --> src.app.layout { DEFAULT_LOCALE, getDirection }
    src.lib.i18n.server --> src.app.layout { getRequestLocale, loadServerMessages }
    "src/components/sidebar-state-utils" --> src.app.layout { sidebarBootstrapScript }
    "src/components/theme-utils" --> src.app.layout { themeBootstrapScript }
    "src/app/home-server-utils" --> src.app.layout { getHomeBranding }
    "src/components/ui/confirm-dialog" --> src.components.providers { ConfirmDialogHost }
    "src/components/mailbox-provider-utils" --> src.components.providers { clearMailboxClientState }
    "src/components/branding-provider" --> src.components.providers { BrandingProvider }
    "src/lib/branding/types.d" --> src.components.providers { Branding }
    "src/components/new-message-popup" --> src.components.providers { NewMessagePopup }
    "src/components/pwa-service-worker" --> src.components.providers { PwaServiceWorker }
    "src/components/theme-sync" --> src.components.providers { ThemeSync }
    "src/hooks/use-message-polling" --> src.components.providers { useMessagePolling }
    src.hooks.utils --> src.components.providers { clearMessageClientState }
    "src/lib/messages/detail-cache" --> src.components.providers { clearMessageDetailCache }
    "src/hooks/use-current-user" --> src.components.providers { clearCurrentUserCache }
    src.lib.auth.client --> src.components.providers { AUTH_SESSION_CHANGED_EVENT }
    "src/lib/auth/client-types.d" --> src.components.providers { AuthSessionChangedDetail }
    src.components.icons --> "src/components/new-message-popup" { Mail, X }
    src.lib.email.address --> "src/components/new-message-popup" { getEmailDisplayName }
    "src/components/language-provider" --> "src/components/new-message-popup" { useLanguage }
    "src/components/new-message-popup-types.d" --> "src/components/new-message-popup" {
        NewMessagePopupProps,
    }
    src.lib.push.client --> "src/components/pwa-service-worker" { registerMailflareServiceWorker }
    "src/components/theme-utils" --> "src/components/theme-sync" {
        THEME_CHANGED_EVENT,
        applyTheme,
        readThemePreference,
    }
    src.lib.auth.client --> "src/hooks/use-message-polling" {
        AUTH_SESSION_CHANGED_EVENT,
        getClientSessionToken,
    }
    "src/hooks/message-realtime-types.d" --> "src/hooks/use-message-polling" {
        MessageRealtimeState,
        NewMessageEvent,
        RealtimeChannelMessage,
    }
    "src/hooks/message-realtime-utils" --> "src/hooks/use-message-polling" {
        REALTIME_FALLBACK_INTERVAL_MS,
        REALTIME_HEARTBEAT_INTERVAL_MS,
        countsDeltaForNewMessage,
        getRealtimeWebSocketUrl,
        getReconnectDelay,
        parseNewMessageEvent,
        showBrowserNewMessageNotification,
    }
    src.lib.cloudflare --> src.app.mcp.route { getEnv }
    src.lib.mcp.auth --> src.app.mcp.route { authenticateMcpRequest }
    src.lib.mcp.server --> src.app.mcp.route { createMailflareMcpHandler }
    "src/lib/agent/rate-limit" --> src.app.mcp.route { allowAgentRequest }
    src.db.index --> src.lib.mcp.auth { getDb }
    src.db.schema.index --> src.lib.mcp.auth { apiKeys, mcpKeyMailboxes, users }
    "src/lib/api-keys" --> src.lib.mcp.auth { parseScopes }
    "src/lib/api/find-api-key" --> src.lib.mcp.auth { findApiKeyForSecret }
    src.lib.mailboxes.access --> src.lib.mcp.auth { getMailboxAccessLevel }
    src.lib.api.scopes --> src.lib.mcp.auth { ADMIN_API_KEY_SCOPES }
    "src/lib/mcp/types.d" --> src.lib.mcp.auth { McpPrincipal }
    src.db.index --> src.lib.mcp.server { getDb }
    src.db.schema.index --> src.lib.mcp.server { agentSendApprovals, messages }
    src.lib.mailboxes.access --> src.lib.mcp.server {
        getMailboxAccessLevel,
        listAccessibleMailboxes,
    }
    src.lib.agent.tools --> src.lib.mcp.server {
        EMAIL_TOOL_NAMES,
        emailToolDescriptions,
        emailToolSchemas,
        runEmailTool,
    }
    "src/lib/agent/edit-draft" --> src.lib.mcp.server { editAgentDraft }
    src.lib.agent.approvals.utils --> src.lib.mcp.server { getAgentSendRequest, requestAgentSend }
    src.lib.email.scheduled --> src.lib.mcp.server { cancelScheduledSend, getScheduledTime }
    src.lib.notes.service --> src.lib.mcp.server {
        CONVERSATION_NOTE_MAX_LENGTH,
        addConversationNote,
        conversationForUser,
        deleteConversationNote,
        listConversationNotes,
        updateConversationNote,
    }
    "src/lib/agent/types.d" --> src.lib.mcp.server { EmailToolName }
    "src/lib/mcp/types.d" --> src.lib.mcp.server { McpPrincipal }
    "src/lib/mcp/admin-tools" --> src.lib.mcp.server { registerAdminMcpTools }
    src.lib.calendar.tools --> src.lib.mcp.server {
        CALENDAR_TOOL_NAMES,
        calendarToolDescriptions,
        calendarToolSchemas,
        calendarToolScope,
        runCalendarTool,
    }
    src.app.api.v1.domains.route --> "src/lib/mcp/admin-tools" { GET, POST }
    "src/app/api/v1/domains/[id]/route" --> "src/lib/mcp/admin-tools" { DELETE, GET }
    "src/app/api/v1/domains/[id]/dns/route" --> "src/lib/mcp/admin-tools" { GET }
    "src/app/api/v1/domains/[id]/dns/setup/route" --> "src/lib/mcp/admin-tools" { POST }
    src.app.api.v1.accounts.route --> "src/lib/mcp/admin-tools" { GET, POST }
    "src/app/api/v1/accounts/[id]/route" --> "src/lib/mcp/admin-tools" { GET, PATCH }
    src.app.api.v1.mailboxes.route --> "src/lib/mcp/admin-tools" { GET, POST }
    "src/app/api/v1/mailboxes/[id]/route" --> "src/lib/mcp/admin-tools" { DELETE, GET, PATCH }
    src.app.api.v1.storage.route --> "src/lib/mcp/admin-tools" { GET, POST }
    "src/lib/mcp/types.d" --> "src/lib/mcp/admin-tools" { McpPrincipal }
    src.app.utils --> src.app.page { heroMessages, sidebarItems }
    src.components.icons --> src.app.page { Inbox, Mail, Search, ShieldCheck }
    src.lib.i18n.server --> src.app.page { getServerTranslator }
    src.lib.auth.cookies --> src.app.page { getCurrentUser }
    src.lib.cloudflare --> src.app.page { getEnv }
    "src/components/language-selector" --> src.app.page { LanguageSelector }
    "src/app/home-server-utils" --> src.app.page { getHomeBranding }
    "src/app/home-auth" --> src.app.page { HomeAuthProvider }
    "src/app/home-header-actions" --> src.app.page { HomeHeaderActions }
    "src/app/home-hero-actions" --> src.app.page { HomeHeroActions }
    "src/components/admin-nav" --> "src/components/dashboard-shell" { AdminNav }
    "src/components/dashboard-nav" --> "src/components/dashboard-shell" { DashboardNav }
    "src/components/language-provider" --> "src/components/logout-button" { useLanguage }
    src.components.ui.button --> "src/components/logout-button" { Button }
    src.lib.auth.logout --> "src/components/logout-button" { logoutClientSession }
    "src/components/language-provider" --> "src/components/messages/spam-score-details" {
        useLanguage,
    }
    "src/components/messages/spam-score-details-types.d" --> "src/components/messages/spam-score-details" {
        SpamScoreDetailsProps,
    }
    "src/components/messages/spam-score-details-utils" --> "src/components/messages/spam-score-details" {
        parseSpamSignals,
    }
    "src/lib/spam/types.d" --> "src/components/messages/spam-score-details-utils" { SpamSignal }
    src.components.icons --> "src/components/settings/current-mailbox-form" { Save }
    "src/components/language-provider" --> "src/components/settings/current-mailbox-form" {
        useLanguage,
    }
    "src/components/mailbox-provider" --> "src/components/settings/current-mailbox-form" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/components/settings/current-mailbox-form" { Button }
    src.components.ui.card --> "src/components/settings/current-mailbox-form" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    src.components.ui.input --> "src/components/settings/current-mailbox-form" { Input }
    src.components.ui.label --> "src/components/settings/current-mailbox-form" { Label }
    src.components.ui.skeleton --> "src/components/settings/current-mailbox-form" { Skeleton }
    "src/components/settings/profile-avatar-form" --> "src/components/settings/current-mailbox-form" {
        ProfileAvatarForm,
    }
    src.components.settings.utils --> "src/components/settings/current-mailbox-form" {
        getMailboxAddress,
        updateCurrentMailboxName,
    }
    src.components.icons --> "src/components/settings/import-messages" { Upload }
    "src/components/language-provider" --> "src/components/settings/import-messages" { useLanguage }
    "src/components/mailbox-provider" --> "src/components/settings/import-messages" {
        useSelectedMailbox,
    }
    src.components.ui.button --> "src/components/settings/import-messages" { Button }
    src.components.ui.card --> "src/components/settings/import-messages" {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    src.components.ui.label --> "src/components/settings/import-messages" { Label }
    src.components.ui.input --> "src/components/settings/import-messages" { Input }
    "src/components/settings/import-messages-types.d" --> "src/components/settings/import-messages" {
        ImportMessagesProps,
        ImportMessagesResult,
    }
    "src/components/settings/import-messages-utils" --> "src/components/settings/import-messages" {
        importMessageFiles,
    }
    src.lib.realtime.revision --> src.lib.realtime.hub { getUserMailRevision }
    "src/lib/realtime/types.d" --> src.lib.realtime.hub {
        AgentDraftNotification,
        NewMessageNotification,
        RevisionNotification,
        RevisionPing,
    }
    src.db.schema.index --> "tests/fixtures/inspect-schema";
    "src/lib/update/auto-update" --> worker { runAutoUpdate }
    "src/db/with-database" --> worker { withDatabase }
    src.lib.storage.index --> worker { withStorage }
    src.lib.email.inbound --> worker { InboundQueueMessage, processInboundMessage, storeRawToR2 }
    src.lib.email.send --> worker { OutboundQueueMessage, processOutboundQueue }
    "worker-utils" --> worker {
        isImportJobMessage,
        isInboundQueueMessage,
        isWebhookRetryMessage,
        settleFailedInboundMessage,
        withD1BookmarkCookie,
        withD1ReadSession,
    }
    "src/lib/d1-session-context" --> worker { runWithD1Session }
    "src/lib/email/raw-sweeper" --> worker { sweepOrphanedRawMail }
    src.lib.messages.actions.claims --> worker { pruneExpiredMessageActionUndoClaims }
    src.lib.import.jobs --> worker { processImportJob, sweepImportJobs }
    src.lib.email.webhooks --> worker { WebhookRetryMessage, processWebhookRetry }
    src.lib.email.incoming --> worker { forwardMessage, resolveIncomingMail }
    src.lib.deliverability.ingest --> worker { createBatchBudget }
    src.lib.auth.session --> worker { getUserFromSession }
    src.lib.realtime.utils --> worker { getSessionTokenFromRequest }
    "src/lib/email/inbound-attachments" --> worker { inboundAttachmentLimitReasonFromRaw }
    src.lib.auth.origin --> worker { hasValidSessionMutationOrigin }
    "src/lib/email/account-forwarding" --> worker {
        MAILFLARE_FORWARDED_HEADER,
        getAccountForwardingDestination,
        isForwardedMarkerValid,
    }
    src.lib.backups.runner --> worker { runScheduledDatabaseBackup }
    src.lib.agent.jobs.utils --> worker { processAgentDraftJob }
    src.lib.agent.maintenance --> worker { runAgentMaintenance }
    "src/lib/email/trash-retention" --> worker { runTrashRetention }
    src.lib.drive.retention --> worker { runDriveTrashRetention }
    src.lib.accounts.deletion --> worker { runAccountRetention }
    src.lib.auth.purge --> worker { purgeExpiredAuthRows }
    src.lib.jmap.changes --> worker { runJmapChangeRetention }
    src.lib.dav.changes --> worker { runDavChangeRetention }
    "src/lib/follow-ups/service" --> worker { runFollowUpReminders }
    src.lib.promotions.backfill --> worker { runPromotionsBackfill }
    src.lib.calendar.reminders --> worker { runCalendarReminders }
    src.lib.dav.handler --> worker { handleDavRequest, isDavPath }
    src.lib.deliverability.daily --> worker { runDeliverabilityDaily }
    "src/lib/deliverability/mta-sts" --> worker { guardMtaStsHost, isMtaStsHost }
    src.lib.realtime.hub --> worker { RealtimeHub }
}
