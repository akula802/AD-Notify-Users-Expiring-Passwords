# AD-Notify-Users-Expiring-Passwords
A set of scripts to prep AD users with email information, and notify via email those whose passwords will soon expire.

It's intended to run daily as a scheduled task, and leaves an entry in the event log that can be monitored by RMM.

Will send the user an email at 10, 5, and 1 days to expiration.
