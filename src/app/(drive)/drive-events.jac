# STORAGE carries a `DriveStorageDetail` whenever a listing loads; FOLDERS follows a load so the
# sidebar can refresh its folder list; REFRESH asks the open listing to reload (e.g. a new folder).
glob DRIVE_UPLOAD_EVENT: str = "mailflare:drive-upload",
     DRIVE_NEW_FOLDER_EVENT: str = "mailflare:drive-new-folder",
     DRIVE_STORAGE_EVENT: str = "mailflare:drive-storage",
     DRIVE_FOLDERS_EVENT: str = "mailflare:drive-folders",
     DRIVE_REFRESH_EVENT: str = "mailflare:drive-refresh";
type DriveStorageDetail = any;
