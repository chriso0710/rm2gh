# RM2GH - Migrate your project issues from Redmine to Github

Use this ruby script to migrate all your issues from a redmine project to a github project.

## Features

* migrates all issues from a redmine project
* uses redmine and github REST APIs
* exports a single JSON file for every redmine issues
* uses mappings for redmine fields to github labels, creates github labels as needed
* creates github issues text in formatted markdown (header, quotes, etc.) with i18n text
* handles redmine journals and comments
* keeps the original JSON markdown data in the github issue for reference 
* closes issue in github depending on redmine status
* gracefully checks and handles github rate limiting (primary and secondary)
* features skipping export/import and dryrun switches
* able to run multiple times, will not create duplicate issues, checks existing issues before creating
* outputs statistics for each platform
* logs every step 
* able to run in VSCode devcontainer, successfully tested with MS ruby 2.6 image

## Tipps and notes

* Read the comments in settings.yml and set your options 
* Please note, that you may need to enable the redmine API beforehand 
* Use a new github repository for testing before creating issues in an existing repository
* Maybe run the github import with a couple of issues (JSON files) from a separate directory first
* Play around with skip and dryrun settings before creating real issues
* Take a close look at the redmine statistics and review your label mappings accordingly

## Usage

1. All settings have to be in settings.yml. Rename the settings-example.yml to settings.yml:
```
cp settings-example.yml settings.yml
```

2. Set your redmine host, redmine project id, github repo, access tokens, mappings, etc. in settings.yml. See the comments in the file.
There are mappings for tracker, priority and category fields from redmine to github labels. Mappings are case insensitive. 
redmine users will not be mapped to github collaborateurs.

3. Run the script with
```
ruby rm2gh.rb
```
Use skipping and dryrun (defaults to true) switches to test your run. Verify that all redmine issues are saved in your json directory as separate files. Verify your mappings for github labels. 

4. Set dryrun to false and run rm2gh again. 
github is quite strict with rate limiting, but rm2gh should be able to handle github rate limits. Depending on the number of issues, processing and creating will take a while. Please be patient and see the log.

## Contributing

I would like to hear from you. Comments, ideas, questions, tips, tests and pull requests are welcome.

## License

See [MIT License](LICENSE.txt)