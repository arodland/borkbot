This is Borkbot, a marginally more modern model of sporksbot by beez.
Improvement include:

* The old and unmaintained Net::IRC is replaced by Mojo::IRC.
* Fully async bot operation using Mojo::IOLoop, Mojo::UserAgent, and Mojo::Pg.
* YAML configuration.
* Easier plugin authoring, with more descriptive IRC events and a simpler means
  of handling them.
* Generally tidier code.

### Instructions for running the bot:

1. Install [PostgreSQL](https://www.postgresql.org/) server, if you haven't
   already, and create a user and database for borkbot.
2. Load the schema contained in borkbot.sql.
3. On your IRC network of choice, create a "control channel" whose members will
   have privileged access to the bot, and password-protect it.
4. Copy borkbot.yaml.example to borkbot.yaml and edit it, setting the IRC
   server, bot nickname, and passwords appropriately. Add any additional modules
   you want loaded to the "modules" section.
5. Run `perl bot.pl`.
