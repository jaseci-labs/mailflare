glob MAX_SOURCE_AVATAR_SIZE: int = 10 * 1024 * 1024;

glob:priv ALLOWED: any = new(globalThis.Set, "image/jpeg image/png image/webp image/gif".split()),
          oops: any = lambda -> any { new(globalThis.Error, "Unable to process this image") };

def:priv canvas_blob(canvas: any, quality: any) -> any {
    def run(yes: any, no: any) {
        done = lambda (b: any) -> any { no(oops()) if not b or b.type != "image/webp" else yes(b) };
        canvas.toBlob(done, "image/webp", quality);
    }
    return new(globalThis.Promise, run);
}

async def:priv resize(image: any, side: int, quality: any) -> any {
    (m, canvas) = (globalThis.Math, globalThis.document.createElement("canvas"));
    scale = m.min(1, side / m.max(image.width, image.height));
    canvas.width = m.max(1, m.round(image.width * scale));
    canvas.height = m.max(1, m.round(image.height * scale));
    context = canvas.getContext("2d");
    if not context {
        raise oops();
    }
    context.imageSmoothingEnabled = True;
    context.imageSmoothingQuality = "high";
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    return await canvas_blob(canvas, quality);
}

async def appendOptimizedAvatar(form: any, source: any) {
    if not ALLOWED.has(source.type) {
        raise new(globalThis.Error, "Use a JPEG, PNG, WebP, or GIF image");
    } elif source.size > MAX_SOURCE_AVATAR_SIZE {
        raise new(globalThis.Error, "Image must be 10 MB or smaller");
    }
    try {
        bmp = await globalThis.createImageBitmap(source);
    } except Exception {
        raise oops();
    }
    try {
        (big, small) = await globalThis.Promise.all([resize(bmp, 512, 0.85), resize(bmp, 16, 0.7)]);
        form.set("file", big, "avatar.webp");
        form.set("preview", small, "avatar-preview.webp");
    } finally {
        bmp.close();
    }
}
