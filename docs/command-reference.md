# Command Reference

```bash
shuk                     # help/banner
shuk setup               # link shuk into ~/.local/bin
shuk doctor              # check tools and Shukhood state
shuk backup              # backup safe configs
shuk secrets check       # check secret presence without printing values
shuk secrets init        # create ~/.hermes/.env from template if missing

shuk hermes              # launch Hermes profile shukhood
shuk hermes raw          # raw official Hermes
shuk hermes setup        # create/apply profile, skills, links
shuk hermes setup --dry-run
shuk hermes doctor
shuk hermes backup
shuk hermes update
```
