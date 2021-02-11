![Shrine Logo](logo/shrine-cr-logo-small.png)

# shrine.cr

![Build Status](https://github.com/jetrockets/shrine.cr/workflows/specs/badge.svg)
[![GitHub release](https://img.shields.io/github/release/jetrockets/shrine.cr.svg)](https://GitHub.com/jetrockets/shrine.cr/releases/)
[![GitHub license](https://img.shields.io/github/license/jetrockets/shrine.cr)](https://github.com/jetrockets/shrine.cr/blob/master/LICENSE)
[![Join the chat at https://gitter.im/shrine-cr/community](https://badges.gitter.im/shrine-cr/community.svg)](https://gitter.im/shrine-cr/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Shrine is a toolkit for file attachments in Crystal applications. Heavily inspired by [Shrine for Ruby](https://shrinerb.com).

## Documentation

[https://jetrockets.github.io/shrine.cr](https://jetrockets.github.io/shrine.cr)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     shrine:
       github: jetrockets/shrine.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "shrine"
```

Shrine.cr is under heavy development!

First of all you should configure `Shrine`.

``` crystal
Shrine.configure do |config|
  config.storages["cache"] = Storage::FileSystem.new("uploads", prefix: "cache")
  config.storages["store"] = Storage::FileSystem.new("uploads")
end
```

Now you can use `Shrine` directly to upload your files.

``` crystal
Shrine.upload(file, "store")
```

`Shrine.upload` method supports additional argument just like Shrine.rb. For example we want our file to have a custom filename.

``` crystal
Shrine.upload(file, "store", metadata: { "filename" => "foo.bar" })
```

### Custom uploaders

To implement custom uploader class just inherit it from `Shrine`. You can override `Shrine` methods to implement custom logic. Here is an example how to create a custom file location.

``` crystal
class FileImport::AssetUploader < Shrine
  def generate_location(io : IO | UploadedFile, metadata, context, **options)
    name = super(io, metadata, **options)

    File.join("imports", context[:model].id.to_s, name)
  end
end

FileImport::AssetUploader.upload(file, "store", context: { model: YOUR_ORM_MODEL } })
```

### S3 storage

#### Creating a Client

``` crystal
client = Awscr::S3::Client.new("region", "key", "secret")
```

For S3 compatible services, like DigitalOcean Spaces or Minio, you'll need to set a custom endpoint:

``` crystal
client = Awscr::S3::Client.new("nyc3", "key", "secret", endpoint: "https://nyc3.digitaloceanspaces.com")
```


#### Create a S3 storage

The storage is initialized by providing your bucket and client:

```crystal
storage = Shrine::Storage::S3.new(bucket: "bucket_name", client: client, prefix: "prefix")
```

Sometimes you'll want to add additional upload options to all S3 uploads. You can do that by passing the :upload_options option:

```crystal
storage = Shrine::Storage::S3.new(bucket: "bucket_name", client: client, upload_options: { "x-amz-acl"=> "public-read" })
```

You can tell S3 storage to make uploads public:

```crystal
storage = Shrine::Storage::S3.new(bucket: "bucket_name", client: client, public: true)
```

### ORM usage example

Currently ORM adapters are not implmented.

#### Granite.

``` crystal
class FileImport < Granite::Base
  connection pg
  table file_imports

  column id : Int64, primary: true
  column asset_data : Shrine::UploadedFile, converter: Granite::Converters::Json(Shrine::UploadedFile, JSON::Any)

  after_save do
    if @asset_changed && @asset_data
      @asset_data = FileImport::AssetUploader.store(@asset_data.not_nil!, move: true, context: { model: self })
      @asset_changed = false

      save!
    end
  end

  def asset=(upload : Amber::Router::File)
    @asset_data = FileImport::AssetUploader.cache(upload.file, metadata: { filename: upload.filename })
    @asset_changed = true
  end
end

```

#### Jennifer

``` crystal
class FileImport < Jennifer::Model::Base
  @asset_changed : Bool | Nil

  with_timestamps

  mapping(
    id: Primary32,
    asset_data: JSON::Any?,
    created_at: Time?,
    updated_at: Time?
  )

  after_save :move_to_store

  def asset=(upload : Amber::Router::File)
    self.asset_data = JSON.parse(FileImport::AssetUploader.cache(upload.file, metadata: { filename: upload.filename }).to_json)
    asset_changed! if asset_data
  end

  def asset
    Shrine::UploadedFile.from_json(asset_data.not_nil!.to_json) if asset_data
  end

  def asset_changed?
    @asset_changed || false
  end

  private def asset_changed!
    @asset_changed = true
  end

  private def move_to_store
    if asset_changed?
      self.asset_data = JSON.parse(FileImport::AssetUploader.store(asset.not_nil!, move: true, context: { model: self }).to_json)
      @asset_changed = false
      save!
    end
  end
end

```

## Plugins

Shrine.cr has a plugins interface similar to Shrine.rb. You can extend functionality of uploaders inherited from `Shrine` and also extend `UploadedFile` class.

### Determine MIME Type

The `DetermineMimeType` plugin is used to get mime type of uploaded file in several ways.

``` crystal

require "shrine/plugins/determine_mime_type"

class Uploader < Shrine
  load_plugin(
    Shrine::Plugins::DetermineMimeType,
    analyzer: Shrine::Plugins::DetermineMimeType::Tools::File
  )

  finalize_plugins!
end
```
**Analyzers**


The following analyzers are accepted:

| Name | Description |
| --- | --- |
| `File`| (**Default**). Uses the file utility to determine the MIME type from file contents. It is installed by default on most operating systems. |
| `Mime` | Uses the [MIME.from_filename](https://crystal-lang.org/api/0.31.1/MIME.html) method to determine the MIME type from file.|
| `ContentType` | Retrieves the value of the `#content_type` attribute of the IO object. Note that this value normally comes from the "Content-Type" request header, so it's not guaranteed to hold the actual MIME type of the file. |


### Add Metadata

The `AddMetadata` plugin provides a convenient method for extracting and adding custom metadata values.

``` crystal
require "base64"
require "shrine/plugins/add_metadata"

class Uploader < Shrine
  load_plugin(Shrine::Plugins::AddMetadata)

  add_metadata :signature, -> {
    Base64.encode(io.gets_to_end)
  }

  finalize_plugins!
end
```

The above will add `"signature"` to the metadata hash.

``` crystal
image.metadata["signature"]
```

**Multiple values**

You can also extract multiple metadata values at once.

``` crystal
class Uploader < Shrine
  load_plugin(Shrine::Plugins::AddMetadata)

  add_metadata :multiple_values, -> {
    text = io.gets_to_end

    Shrine::UploadedFile::MetadataType{
      "custom_1" => text,
      "custom_2" => text * 2
    }
  }

  finalize_plugins!
end
```

``` crystal
image.metadata["custom_1"]
image.metadata["custom_2"]
```

### Store Dimensions

The `StoreDimensions` plugin extracts dimensions of uploaded images and stores them into the metadata. Additional dependency [https://github.com/jetrockets/fastimage.cr](https://github.com/jetrockets/fastimage.cr) needed for this plugin.

``` crystal

require "fastimage"
require "shrine/plugins/store_dimensions"

class Uploader < Shrine
  load_plugin(Shrine::Plugins::StoreDimensions,
    analyzer: Shrine::Plugins::StoreDimensions::Tools::FastImage)

  finalize_plugins!
end
```

``` crystal
image.metadata["width"]
image.metadata["height"]
```

**Analyzers**

The following analyzers are accepted:


| Name | Description |
| --- | --- |
| `FastImage` | (**Default**) Uses the [FastImage](https://github.com/jetrockets/fastimage.cr). |
| `Identify` | A built-in solution that wrapps ImageMagick's `identify` command. |

## Feature Progress

In no particular order, features that have been implemented and are planned.
Items not marked as completed may have partial implementations.

- [X] Shrine
- [X] Shrine::UploadedFile
    - [ ] ==
    - [X] #original_filename
    - [X] #extension
    - [X] #size
    - [X] #mime_type
    - [X] #close
    - [X] #url
    - [X] #exists?
    - [X] #open
    - [X] #download
    - [X] #stream
    - [X] #replace
    - [X] #delete
- [X] Shrine::Attacher
- [ ] Shrine::Attachment
- [ ] Shrine::Storage
    - [X] Shrine::Storage::Memory
    - [X] Shrine::Storage::FileSystem
    - [X] Shrine::Storage::S3
- [ ] Uploaders
    - [X] Custom uploaders
    - [ ] Derivatives
- [ ] ORM adapters
    - [ ] `Granite` [https://github.com/amberframework/granite](https://github.com/amberframework/granite)
    - [ ] `crecto` [https://github.com/Crecto/crecto](https://github.com/Crecto/crecto)
    - [ ] `jennifer.cr` [https://github.com/imdrasil/jennifer.cr](https://github.com/imdrasil/jennifer.cr)
    - [ ] `Avram` [https://github.com/luckyframework/avram](https://github.com/luckyframework/avram)
- [X] Plugins
- [ ] Background processing


## Contributing

1. Fork it (<https://github.com/your-github-user/shrine.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Igor Alexandrov](https://github.com/igor-alexandrov) - creator and maintainer
- [Arina Shmeleva](https://github.com/arina1004) - helped with S3 Storage
- [Mick Wout](https://github.com/wout) - Plugins and Lucky integration
