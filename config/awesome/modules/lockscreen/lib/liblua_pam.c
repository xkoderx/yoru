/* Minimal replacement for yoru's precompiled modules/lockscreen/lib/liblua_pam.so
 *
 * The .so shipped in the repo was built against Lua 5.4 (NEEDED liblua.so.5.4)
 * and cannot load under awesome-git, which now runs Lua 5.5:
 *   "version mismatch: app. needs 504.0, Lua core provides 505.0"
 *
 * This re-implements the same single function the lockscreen uses:
 *   pam.auth_current_user(password) -> boolean
 * using PAM service "login" for the current user (getuid/getpwuid),
 * same as the original (see strings on the shipped .so).
 *
 * Build: gcc -shared -fPIC -I/usr/include -o liblua_pam.so liblua_pam.c -llua -lpam
 */
#include <lua.h>
#include <lauxlib.h>

#include <pwd.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <security/pam_appl.h>

static const char *g_password;

static int conv_cb(int n, const struct pam_message **msg,
                   struct pam_response **resp, void *data)
{
    (void)data;
    struct pam_response *r = calloc((size_t)n, sizeof(*r));
    if (!r)
        return PAM_BUF_ERR;
    for (int i = 0; i < n; i++) {
        if (msg[i]->msg_style == PAM_PROMPT_ECHO_OFF ||
            msg[i]->msg_style == PAM_PROMPT_ECHO_ON) {
            r[i].resp = strdup(g_password ? g_password : "");
            r[i].resp_retcode = 0;
        }
    }
    *resp = r;
    return PAM_SUCCESS;
}

static int l_auth_current_user(lua_State *L)
{
    const char *pw = luaL_checklstring(L, 1, NULL);
    struct passwd *pwd = getpwuid(getuid());
    if (!pwd) {
        lua_pushboolean(L, 0);
        return 1;
    }
    struct pam_conv conv = { conv_cb, NULL };
    pam_handle_t *pamh = NULL;
    g_password = pw;
    int ret = pam_start("login", pwd->pw_name, &conv, &pamh);
    if (ret == PAM_SUCCESS)
        ret = pam_authenticate(pamh, 0);
    if (pamh)
        pam_end(pamh, ret);
    g_password = NULL;
    lua_pushboolean(L, ret == PAM_SUCCESS);
    return 1;
}

static const luaL_Reg funcs[] = {
    { "auth_current_user", l_auth_current_user },
    { NULL, NULL }
};

int luaopen_liblua_pam(lua_State *L)
{
    luaL_newlib(L, funcs);
    return 1;
}
