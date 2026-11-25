glob DRIVE_CATEGORIES: list[str] = ["photos", "videos", "documents", "others"];
type DriveCategory = any;

def isDriveCategory(value: any) -> bool {
    return bool(value) and value in DRIVE_CATEGORIES;
}
