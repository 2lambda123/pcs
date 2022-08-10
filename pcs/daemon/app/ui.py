import os.path

from pcs.daemon import session
from pcs.daemon.app.auth import (
    NotAuthorizedException,
    PasswordAuthProvider,
    SessionAuthProvider,
)
from pcs.daemon.app.common import (
    BaseHandler,
    RoutesType,
)
from pcs.daemon.app.ui_common import (
    AjaxMixin,
    StaticFile,
)
from pcs.lib.auth.provider import AuthProvider


class SPAHandler(BaseHandler):
    __index = None
    __fallback = None

    def initialize(self, index: str, fallback: str) -> None:
        # pylint: disable=arguments-differ
        self.__index = index
        self.__fallback = fallback

    def get(self, *args, **kwargs):
        del args, kwargs
        self.render(
            self.__index
            if os.path.isfile(str(self.__index))
            # spa is probably not installed
            else self.__fallback
        )


class Login(SPAHandler, AjaxMixin):
    _password_auth_provider: PasswordAuthProvider
    _session_auth_provider: SessionAuthProvider

    def initialize(
        self,
        session_storage: session.Storage,
        auth_provider: AuthProvider,
        index: str,
        fallback: str,
    ) -> None:
        # pylint: disable=arguments-differ
        SPAHandler.initialize(self, index, fallback)
        self._password_auth_provider = PasswordAuthProvider(self, auth_provider)
        self._session_auth_provider = SessionAuthProvider(
            self, auth_provider, session_storage
        )

    def prepare(self) -> None:
        self._session_auth_provider.init_session()

    async def post(self, *args, **kwargs):
        del args, kwargs
        # This is the way of old (ruby) pcsd. Post login generates a session
        # cookie. No matter if authentication succeeded or failed.
        try:
            self._session_auth_provider.update_session(
                await self._password_auth_provider.auth_by_username_password(
                    self.get_body_argument("username"),
                    self.get_body_argument("password"),
                )
            )
        except NotAuthorizedException as e:
            raise self.unauthorized() from e


class Logout(AjaxMixin, BaseHandler):
    """
    Logout handles url for logout. It is used for both ajax and non-ajax
    requests.
    """

    _auth_provider: SessionAuthProvider

    def initialize(
        self,
        session_storage: session.Storage,
        auth_provider: AuthProvider,
    ) -> None:
        # pylint: disable=arguments-differ
        self._auth_provider = SessionAuthProvider(
            self, auth_provider, session_storage
        )

    def prepare(self) -> None:
        self._auth_provider.init_session()

    async def get(self, *args, **kwargs):
        del args, kwargs
        self._auth_provider.session_logout()
        self.write("OK")


class StaticFileMayBe(StaticFile):
    # pylint: disable=abstract-method
    def get(self, *args, **kwargs):
        # pylint: disable=signature-differs
        # pylint: disable=invalid-overridden-method
        if not os.path.isdir(str(self.root)):
            # spa is probably not installed
            self.set_status(404, "Not Found")
            return None
        return super().get(*args, **kwargs)


def get_routes(
    url_prefix: str,
    app_dir: str,
    fallback_page_path: str,
    session_storage: session.Storage,
    auth_provider: AuthProvider,
) -> RoutesType:
    static_path = lambda dir="": dict(path=os.path.join(app_dir, dir))
    pages = dict(
        index=os.path.join(app_dir, "index.html"),
        fallback=fallback_page_path,
    )

    # One possibility is to check if SPA index exists and if does not exists
    # return only route to fallback page. However, it would require to restart
    # pcsd after putting spa. For this reason, routes stay the same, no matter
    # if SPA index exists.

    return [
        (f"{url_prefix}static/(.*)", StaticFileMayBe, static_path("static")),
        (f"{url_prefix}manifest.json", StaticFileMayBe, static_path()),
        (
            f"{url_prefix}login",
            Login,
            dict(
                session_storage=session_storage,
                auth_provider=auth_provider,
                index=os.path.join(app_dir, "index.html"),
                fallback=fallback_page_path,
            ),
        ),
        (
            f"{url_prefix}logout",
            Logout,
            dict(session_storage=session_storage, auth_provider=auth_provider),
        ),
        (f"{url_prefix}.*", SPAHandler, pages),
    ]
