"""Minimal valid PDF 1.4 generator for VeloFleet invoices and receipts."""


def _escape_pdf_text(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace("(", "\\(")
        .replace(")", "\\)")
        .encode("latin-1", "replace")
        .decode("latin-1")
    )


def _format_minor(amount_minor: int, currency: str) -> str:
    sign = "-" if amount_minor < 0 else ""
    whole, cents = divmod(abs(amount_minor), 100)
    return f"{sign}{currency} {whole}.{cents:02d}"


def build_invoice_pdf_bytes(
    *,
    invoice_number: str,
    booking_reference: str,
    customer_name: str,
    issued_at_iso: str,
    currency: str,
    agreed_minor: int,
    extra_minor: int,
    discount_minor: int,
    tax_minor: int,
    total_minor: int,
    status: str,
) -> bytes:
    """Render an authentic PDF 1.4 receipt/invoice document without binary C dependencies."""
    lines = [
        "VeloFleet Chauffeur & Fleet Services - TAX INVOICE",
        f"Invoice No: {invoice_number}    Status: {status.upper()}",
        f"Booking Reference: {booking_reference}",
        f"Customer: {customer_name}",
        f"Issued (UTC): {issued_at_iso}",
        "-" * 60,
        f"Agreed Service Amount : {_format_minor(agreed_minor, currency)}",
        f"Extra Charges / Wait  : {_format_minor(extra_minor, currency)}",
        f"Discounts Applied     : -{_format_minor(discount_minor, currency)}",
        f"Taxes & Levies        : {_format_minor(tax_minor, currency)}",
        "-" * 60,
        f"INVOICE TOTAL         : {_format_minor(total_minor, currency)}",
    ]

    stream_ops = ["BT", "/F1 11 Tf", "50 760 Td", "16 TL"]
    for idx, line in enumerate(lines):
        escaped = _escape_pdf_text(line)
        stream_ops.append(f"({escaped}) Tj" if idx == 0 else f"T* ({escaped}) Tj")
    stream_ops.append("ET")
    content = "\n".join(stream_ops).encode("latin-1")

    objects: list[bytes] = [
        b"1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n",
        b"2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n",
        (
            b"3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
            b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj\n"
        ),
        b"4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n",
        (
            f"5 0 obj << /Length {len(content)} >> stream\n".encode("latin-1")
            + content
            + b"\nendstream endobj\n"
        ),
    ]

    out = bytearray(b"%PDF-1.4\n")
    offsets: list[int] = [0]
    for obj in objects:
        offsets.append(len(out))
        out.extend(obj)

    xref_pos = len(out)
    out.extend(f"xref\n0 {len(offsets)}\n".encode("latin-1"))
    out.extend(b"0000000000 65535 f \n")
    for off in offsets[1:]:
        out.extend(f"{off:010d} 00000 n \n".encode("latin-1"))
    out.extend(
        (f"trailer << /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{xref_pos}\n%%EOF\n").encode(
            "latin-1"
        )
    )
    return bytes(out)
