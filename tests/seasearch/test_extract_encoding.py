import unittest

from seafevents.seasearch.utils.extract import ExtractorFactory


class ExtractEncodingTest(unittest.TestCase):
    def setUp(self):
        self.extractor = ExtractorFactory.get_extractor('document.txt')

    def decode(self, encoded_text):
        return self.extractor.fix_encoding('test-repository', 'document.txt', encoded_text)

    def test_unicode_after_long_ascii_prefix(self):
        for prefix_length in (4096, 8192, 16384, 32768):
            with self.subTest(prefix_length=prefix_length):
                text = 'a' * prefix_length + ' café — 東京'
                self.assertEqual(self.decode(text.encode('utf-8')), text)

    def test_valid_utf8_with_legacy_looking_prefix(self):
        text = ('résumé à bientôt; ' * 300) + '東京'
        self.assertEqual(self.decode(text.encode('utf-8')), text)

    def test_utf8_bom_is_removed(self):
        self.assertEqual(self.decode('café'.encode('utf-8-sig')), 'café')

    def test_ascii_remains_text(self):
        self.assertEqual(self.decode(b'plain text'), 'plain text')

    def test_legacy_windows_encoding(self):
        text = 'café – résumé “quotation”'
        self.assertEqual(self.decode(text.encode('windows-1252')), text)

    def test_legacy_character_after_ascii_prefix(self):
        text = 'a' * 8192 + '–'
        self.assertEqual(self.decode(text.encode('windows-1252')), text)

    def test_utf16_bom_selects_legacy_decoder(self):
        text = 'café 東京'
        self.assertEqual(self.decode(text.encode('utf-16')), text)

    def test_empty_input_has_no_content(self):
        self.assertIsNone(self.decode(b''))

    def test_invalid_text_fails_loudly(self):
        with self.assertRaises(UnicodeError):
            self.decode(bytes((0x81, 0x8d, 0x8f, 0x90, 0x9d)) * 20)


if __name__ == '__main__':
    unittest.main()
