import os.path
from unittest import (
    TestCase,
    mock,
)

from pcs import settings
from pcs.common import file_type_codes
from pcs.common.file import RawFileError
from pcs.common.reports import codes as report_codes
from pcs.lib.booth import config_files
from pcs.lib.booth.config_facade import ConfigFacade

from pcs_test.tools import fixture
from pcs_test.tools.assertions import assert_report_item_list_equal


@mock.patch("os.path.isdir")
@mock.patch("os.listdir")
@mock.patch("os.path.isfile")
class GetAllConfigsFileNamesTest(TestCase):
    def test_booth_config_dir_is_no_dir(
        self, mock_is_file, mock_listdir, mock_isdir
    ):
        mock_isdir.return_value = False
        self.assertEqual([], config_files.get_all_configs_file_names())
        mock_isdir.assert_called_once_with(settings.booth_config_dir)
        self.assertEqual(0, mock_is_file.call_count)
        self.assertEqual(0, mock_listdir.call_count)

    def test_success(self, mock_is_file, mock_listdir, mock_isdir):
        def mock_is_file_fn(file_name):
            if file_name in [
                os.path.join(settings.booth_config_dir, name)
                for name in ("dir.cong", "dir")
            ]:
                return False
            if file_name in [
                os.path.join(settings.booth_config_dir, name)
                for name in (
                    "name1",
                    "name2.conf",
                    "name.conf.conf",
                    ".conf",
                    "name3.conf",
                )
            ]:
                return True

            raise AssertionError("unexpected input")

        mock_isdir.return_value = True
        mock_is_file.side_effect = mock_is_file_fn
        mock_listdir.return_value = [
            "name1",
            "name2.conf",
            "name.conf.conf",
            ".conf",
            "name3.conf",
            "dir.cong",
            "dir",
        ]
        self.assertEqual(
            ["name2.conf", "name.conf.conf", "name3.conf"],
            config_files.get_all_configs_file_names(),
        )
        mock_listdir.assert_called_once_with(settings.booth_config_dir)


class GetAuthfileNameAndData(TestCase):
    def test_no_auth_file(self):
        conf = ConfigFacade.create([], [])
        self.assertEqual(
            (None, None, []), config_files.get_authfile_name_and_data(conf)
        )

    def assert_path_check(self, path):
        conf = ConfigFacade.create([], [])
        conf.set_authfile(path)
        result = config_files.get_authfile_name_and_data(conf)
        self.assertEqual(result[0], None)
        self.assertEqual(result[1], None)
        assert_report_item_list_equal(
            result[2],
            [
                fixture.warn(
                    report_codes.BOOTH_UNSUPPORTED_FILE_LOCATION,
                    file_type_code=file_type_codes.BOOTH_KEY,
                    file_path=path,
                    expected_dir=settings.booth_config_dir,
                ),
            ],
        )

    def test_invalid_path(self):
        self.assert_path_check(f"/not{settings.booth_config_dir}/booth.key")

    def test_not_abs_path(self):
        self.assert_path_check(f"{settings.booth_config_dir}/../booth.key")

    @mock.patch("pcs.common.file.RawFile.read")
    def test_success(self, mock_read):
        key_data = "some key data".encode("utf-8")
        key_name = "my_booth.key"
        mock_read.return_value = key_data
        path = os.path.join(settings.booth_config_dir, key_name)
        conf = ConfigFacade.create([], [])
        conf.set_authfile(path)
        self.assertEqual(
            (key_name, key_data, []),
            config_files.get_authfile_name_and_data(conf),
        )

    @mock.patch("pcs.common.file.RawFile.read")
    def test_read_failure(self, mock_read):
        key_name = "my_booth.key"
        mock_read.side_effect = RawFileError(
            "mock file type", RawFileError.ACTION_READ, "some error"
        )
        path = os.path.join(settings.booth_config_dir, key_name)
        conf = ConfigFacade.create([], [])
        conf.set_authfile(path)
        with self.assertRaises(RawFileError):
            config_files.get_authfile_name_and_data(conf)
