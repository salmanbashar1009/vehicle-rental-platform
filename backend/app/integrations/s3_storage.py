"""S3-compatible object storage adapter with magic-byte upload validation."""

from uuid import uuid4

import boto3
from botocore.client import BaseClient

from app.core.config import get_settings
from app.core.exceptions import ValidationDomainError

MAX_UPLOAD_BYTES = 10 * 1024 * 1024

ALLOWED_SIGNATURES: dict[str, tuple[str, ...]] = {
    "image/jpeg": (".jpg", ".jpeg"),
    "image/png": (".png",),
    "image/webp": (".webp",),
    "application/pdf": (".pdf",),
}


def detect_mime_from_magic(data: bytes) -> str | None:
    """Inspect magic bytes to determine real MIME type safely."""
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    if data.startswith(b"%PDF-"):
        return "application/pdf"
    return None


def validate_upload_bytes(
    data: bytes,
    *,
    filename: str,
    allowed_mimes: frozenset[str],
) -> tuple[str, str]:
    """Validate size, magic-byte MIME, and safe extension; return (mime, ext)."""
    if not data:
        raise ValidationDomainError("Uploaded file is empty.")
    if len(data) > MAX_UPLOAD_BYTES:
        raise ValidationDomainError("Uploaded file exceeds 10 MB limit.")

    detected = detect_mime_from_magic(data)
    if detected is None or detected not in allowed_mimes:
        raise ValidationDomainError("Unsupported or spoofed file type.")

    lowered = filename.lower()
    valid_exts = ALLOWED_SIGNATURES[detected]
    if not any(lowered.endswith(ext) for ext in valid_exts):
        raise ValidationDomainError("File extension does not match file content.")
    return detected, valid_exts[0]


class S3StorageClient:
    """S3/MinIO storage wrapper generating safe UUID keys and presigned URLs."""

    def __init__(self) -> None:
        settings = get_settings()
        self._bucket = settings.s3_bucket_name
        self._public_base = settings.s3_public_base_url.rstrip("/")
        self._client: BaseClient = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint_url,
            aws_access_key_id=settings.s3_access_key,
            aws_secret_access_key=settings.s3_secret_key,
            region_name=settings.s3_region,
        )

    def upload_bytes(self, *, prefix: str, data: bytes, mime: str, ext: str) -> str:
        """Upload validated bytes under a random UUID object key."""
        clean_prefix = prefix.strip("/")
        key = f"{clean_prefix}/{uuid4().hex}{ext}"
        self._client.put_object(
            Bucket=self._bucket,
            Key=key,
            Body=data,
            ContentType=mime,
        )
        return key

    def presign_get(self, key: str, expires_seconds: int = 300) -> str:
        """Return short-lived presigned read URL for private assets."""
        return str(
            self._client.generate_presigned_url(
                "get_object",
                Params={"Bucket": self._bucket, "Key": key},
                ExpiresIn=expires_seconds,
            )
        )

    def public_url(self, key: str) -> str:
        """Return public asset URL for non-sensitive catalogue images."""
        return f"{self._public_base}/{key}"
