/* pamtest SERVICE USER [PASSWORD] -- used by fingerprint-pam.sh test-fallback: run pam_authenticate + acct_mgmt, answer
 * password prompts with PASSWORD, show info messages (and desktop notify). */
#include <security/pam_appl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static const char *pw;
static int conv (int n, const struct pam_message **m, struct pam_response **r, void *d)
{
  *r = calloc (n, sizeof (struct pam_response));
  for (int i = 0; i < n; i++)
    {
      time_t t = time (NULL); char ts[16]; strftime (ts, sizeof ts, "%T", localtime (&t));
      printf ("[%s] PAM msg(%d): %s\n", ts, m[i]->msg_style, m[i]->msg); fflush (stdout);
      if (m[i]->msg_style == PAM_PROMPT_ECHO_OFF || m[i]->msg_style == PAM_PROMPT_ECHO_ON)
        (*r)[i].resp = strdup (pw ? pw : "");
      else if (getenv ("NOTIFY"))
        {
          char cmd[512]; snprintf (cmd, sizeof cmd, "notify-send -r 4242 -u critical -t 0 Fingerprint \"PAM: %s\"", m[i]->msg);
          if (system (cmd)) {}
        }
    }
  return PAM_SUCCESS;
}
int main (int argc, char **argv)
{
  pam_handle_t *h; struct pam_conv c = { conv, NULL };
  pw = argc > 3 ? argv[3] : NULL;
  int r = pam_start (argv[1], argv[2], &c, &h);
  if (r == PAM_SUCCESS) r = pam_authenticate (h, 0);
  if (r == PAM_SUCCESS) r = pam_acct_mgmt (h, 0);
  printf ("RESULT %s %s: %s\n", argv[1], argv[2], pam_strerror (h, r));
  pam_end (h, r);
  return r != PAM_SUCCESS;
}
