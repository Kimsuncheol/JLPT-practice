import unittest

from migrate_reorder_tokens import Morpheme, merge_particles_into_tokens


class MergeTokensTest(unittest.TestCase):
    def test_content_particle_auxiliary(self):
        raw = [Morpheme("毎朝", "名詞"), Morpheme("パン", "名詞"),
               Morpheme("を", "助詞"), Morpheme("食べ", "動詞"),
               Morpheme("ます", "助動詞"), Morpheme("。", "補助記号")]
        self.assertEqual(merge_particles_into_tokens(raw),
                         ["毎朝", "パンを", "食べます"])

    def test_repeated_content_words(self):
        raw = [Morpheme("猫", "名詞"), Morpheme("も", "助詞"),
               Morpheme("猫", "名詞"), Morpheme("も", "助詞"),
               Morpheme("。", "補助記号")]
        self.assertEqual(merge_particles_into_tokens(raw), ["猫も", "猫も"])


if __name__ == "__main__":
    unittest.main()
