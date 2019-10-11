# shrine.cr

Shrine is a toolkit for file attachments in Crystal applications. Heavily inspired by Shrine for Ruby

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     shrine.cr:
       github: jetrockets/shrine.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "shrine.cr"
```

### Feature Progress

In no particular order, features that have been implemented and are planned.
Items not marked as completed may have partial implementations.

- [X] Shrine
- [X] Shrine::UploadedFile
- [ ] Shrine::Attacher
- [ ] Shrine::Attachment
- [ ] Shrine::Storage
    - [X] Shrine::Storage::Memory
    - [X] Shrine::Storage::FileSystem
    - [ ] Shrine::Storage::S3
- [ ] Uploaders
    - [X] Custom uploaders
    - [ ] Deviations
- [ ] Plugins



## Contributing

1. Fork it (<https://github.com/your-github-user/shrine.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Igor Alexandrov](https://github.com/igor-alexandrov) - creator and maintainer
