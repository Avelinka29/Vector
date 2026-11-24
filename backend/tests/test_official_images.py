from app.scripts.import_official_images import ImageMetadataParser, safe_name


def test_extracts_social_image_metadata():
    parser = ImageMetadataParser()
    parser.feed('<meta property="og:image" content="/images/building.jpg">'
                '<meta name="twitter:image" content="https://cdn.example.org/card.png">')
    assert parser.candidates == ["/images/building.jpg", "https://cdn.example.org/card.png"]


def test_safe_name_removes_path_characters():
    assert safe_name("college/a:b") == "college_a_b"
