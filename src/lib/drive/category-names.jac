glob DRIVE_CATEGORIES: list[str] = ["photos", "videos", "documents", "others"];

def isDriveCategory(value: any) -> bool {
    return bool(value) and value in DRIVE_CATEGORIES;
}

type DriveCategory = any;
