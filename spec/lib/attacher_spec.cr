require "../spec_helper"

class Uploader < Shrine
end

Spectator.describe "Shrine::Attacher" do
  include FileHelpers

  let(attacher) {
    Shrine::Attacher.new(**NamedTuple.new)
  }

  after_each do
    clear_storages
  end

  describe ".shrine_class" do
    it "returns `Shrine` for `Shrine::Attacher`" do
      expect(
        Shrine::Attacher.shrine_class
      ).to eq(Shrine)
    end

    it "returns uploader class for `<uploader>::Attacher`" do
      expect(
        Uploader::Attacher.shrine_class
      ).to eq(Uploader)
    end
  end

  describe ".from_data" do
    it "instantiates an attacher from file data" do
      file = attacher.upload(fakeio)

      expect(
        Shrine::Attacher.from_data(file.data).file
      ).to eq(file)
    end

    it "forwards additional options to .new" do
      expect(
        Shrine::Attacher.from_data(nil, cache_key: "other_cache").cache_key
      ).to eq("other_cache")
    end
  end

  describe "#assign" do
    it "attaches a file to cache" do
      attacher.assign(fakeio)
      expect(attacher.file.not_nil!.storage_key).to eq("cache")
    end

    it "returns the cached file" do
      file = attacher.assign(fakeio)

      expect(file).to eq(attacher.file)
    end

    # it "ignores empty strings" do
    #   attacher.assign(fakeio)
    #   attacher.assign("")

    #   expect(attacher.attached?).to be_true
    # end

    it "accepts nil" do
      attacher.assign(fakeio)
      attacher.assign(nil)

      expect(attacher.attached?).to be_false
    end

    it "fowards any additional options for upload" do
      attacher.assign(fakeio, location: "foo")

      expect(attacher.file.not_nil!.id).to eq("foo")
    end
  end

  describe "#attach_cached" do
    context "with IO | Shrine::UploadedFile object" do
      it "caches an IO object" do
        attacher.attach_cached(fakeio)

        expect(attacher.file.not_nil!.storage_key).to eq("cache")
      end

      it "caches an UploadedFile object" do
        cached_file = Shrine.upload(fakeio, "cache")
        attacher.attach_cached(cached_file)

        expect(attacher.file.not_nil!.id).to_not eq(cached_file.id)
      end

      it "returns the attached file" do
        file = attacher.attach_cached(fakeio)

        expect(file).to eq(attacher.file)
      end

      context "with custom attacher options" do
        let(attacher) {
          Shrine::Attacher.new(cache_key: "other_cache")
        }

        it "uploads to attacher's temporary storage" do
          attacher.attach_cached(fakeio)
          expect(attacher.file.not_nil!.storage_key).to eq("other_cache")
        end
      end

      it "accepts nils" do
        attacher.attach_cached(fakeio)
        attacher.attach_cached(nil)

        expect(attacher.file).to be_nil
      end

      it "forwards additional options for upload" do
        attacher.attach_cached(fakeio, location: "foo")

        expect(attacher.file.not_nil!.id).to eq("foo")
      end
    end

    context "with uploaded file data" do
      it "accepts JSON data of a cached file" do
        cached_file = Shrine.upload(fakeio, "cache")
        attacher.attach_cached(cached_file.to_json)

        expect(attacher.file).to eq(cached_file)
      end

      it "accepts Hash data of a cached file" do
        cached_file = Shrine.upload(fakeio, "cache")
        attacher.attach_cached(cached_file.data)

        expect(attacher.file).to eq(cached_file)
      end

      it "changes the attachment" do
        cached_file = Shrine.upload(fakeio, "cache")
        attacher.attach_cached(cached_file.data)

        expect(attacher.changed?).to be_true
      end

      it "returns the attached file" do
        cached_file = Shrine.upload(fakeio, "cache")

        expect(attacher.attach_cached(cached_file.data)).to eq(cached_file)
      end

      context "with custom attacher options" do
        let(attacher) {
          Shrine::Attacher.new(cache_key: "other_cache")
        }

        it "uses attacher's temporary storage" do
          cached_file = Shrine.upload(fakeio, "other_cache")
          attacher.attach_cached(cached_file.data)

          expect(attacher.file.not_nil!.storage_key).to eq("other_cache")
        end
      end

      it "rejects non-cached files" do
        stored_file = Shrine.upload(fakeio, "store")

        expect { attacher.attach_cached(stored_file.data) }.to raise_error(Shrine::NotCached)
      end
    end
  end

  describe "#attach" do
    it "uploads the file to permanent storage" do
      attacher.attach(fakeio)

      expect(attacher.file.not_nil!.exists?).to be_true
      expect(attacher.file.not_nil!.storage_key).to eq("store")
    end

    context "with custom attacher options" do
      let(attacher) {
        Shrine::Attacher.new(store_key: "other_cache")
      }

      it "uploads the file to permanent storage" do
        attacher.attach(fakeio)

        expect(attacher.file.not_nil!.exists?).to be_true
        expect(attacher.file.not_nil!.storage_key).to eq("other_cache")
      end
    end

    it "allows specifying a different storage" do
      attacher.attach(fakeio, "other_store")

      expect(attacher.file.not_nil!.exists?).to be_true
      expect(attacher.file.not_nil!.storage_key).to eq("other_store")
    end

    it "forwards additional options for upload" do
      attacher.attach(fakeio, location: "foo")

      expect(attacher.file.not_nil!.id).to eq("foo")
    end

    it "returns the uploaded file" do
      file = attacher.attach(fakeio)

      expect(attacher.file).to eq(file)
    end

    it "changes the attachment" do
      attacher.attach(fakeio)

      expect(attacher.changed?).to be_true
    end

    it "accepts nil" do
      attacher.attach(fakeio)
      attacher.attach(nil)

      expect(attacher.file).to be_nil
    end
  end

  describe "#finalize" do
    it "promotes cached file" do
      attacher.attach_cached(fakeio)
      attacher.finalize

      expect(attacher.file.not_nil!.storage_key).to eq("store")
    end

    it "deletes previous file" do
      previous_file = attacher.attach(fakeio)
      attacher.attach(fakeio)
      attacher.finalize

      expect(previous_file.not_nil!.exists?).to be_false
    end

    it "clears dirty state" do
      attacher.attach(fakeio)
      attacher.finalize

      expect(attacher.changed?).to be_false
    end
  end

  describe "#promote_cached" do
    it "uploads cached file to permanent storage" do
      attacher.attach_cached(fakeio)
      attacher.promote_cached

      expect(attacher.file.not_nil!.storage_key).to eq("store")
    end

    it "doesn't promote if file is not cached" do
      file = attacher.attach(fakeio, storage: "other_store")
      attacher.promote_cached

      expect(attacher.file).to eq(file)
    end

    it "doesn't promote if attachment has not changed" do
      file = Shrine.upload(fakeio, "cache")
      attacher.file = file
      attacher.promote_cached

      expect(attacher.file).to eq(file)
    end

    it "forwards additional options for upload" do
      attacher.attach_cached(fakeio)
      attacher.promote_cached(location: "foo")

      expect(attacher.file.not_nil!.id).to eq("foo")
    end
  end

  describe "#promote" do
    it "uploads attached file to permanent storage" do
      attacher.attach_cached(fakeio)
      attacher.promote

      expect(attacher.file.not_nil!.storage_key).to eq("store")
      expect(attacher.file.not_nil!.exists?).to be_true
    end

    it "returns the promoted file" do
      attacher.attach_cached(fakeio)
      file = attacher.promote

      expect(attacher.file).to eq(file)
    end

    it "allows uploading to a different storage" do
      attacher.attach(fakeio)
      attacher.promote(storage: "other_store")

      expect(attacher.file.not_nil!.storage_key).to eq("other_store")
      expect(attacher.file.not_nil!.exists?).to be_true
    end

    it "forwards additional options for upload" do
      attacher.attach_cached(fakeio)
      attacher.promote(location: "foo")

      expect(attacher.file.not_nil!.id).to eq("foo")
    end

    it "doesn't change the attachment" do
      attacher.file = attacher.upload(fakeio)
      attacher.promote

      expect(attacher.changed?).to be_false
    end
  end

  describe "#upload" do
    it "uploads file to permanent storage" do
      uploaded_file = attacher.upload(fakeio)

      expect(uploaded_file).to be_a(Shrine::UploadedFile)
      expect(uploaded_file.exists?).to be_true
      expect(uploaded_file.storage_key).to eq("store")
    end

    it "uploads file to specified storage" do
      uploaded_file = attacher.upload(fakeio, "other_store")

      expect(uploaded_file.storage_key).to eq("other_store")
    end

    it "forwards additional options" do
      uploaded_file = attacher.upload(fakeio, metadata: {"foo" => "bar"})

      expect(uploaded_file.metadata["foo"]).to eq("bar")
    end
  end

  describe "#destroy_previous" do
    it "deletes previous attached file" do
      previous_file = attacher.attach(fakeio)
      attacher.attach(fakeio)
      attacher.destroy_previous

      expect(previous_file.not_nil!.exists?).to be_false
      expect(attacher.file.not_nil!.exists?).to be_true
    end

    it "deletes only stored files" do
      previous_file = attacher.attach_cached(fakeio)
      attacher.attach(fakeio)
      attacher.destroy_previous

      expect(previous_file.not_nil!.exists?).to be_true
      expect(attacher.file.not_nil!.exists?).to be_true
    end

    it "handles previous attachment being nil" do
      attacher.attach(fakeio)
      attacher.destroy_previous

      expect(attacher.file.not_nil!.exists?).to be_true
    end

    it "skips when attachment hasn't changed" do
      attacher.file = attacher.upload(fakeio)
      attacher.destroy_previous

      expect(attacher.file.not_nil!.exists?).to be_true
    end
  end

  describe "#destroy_attached" do
    it "deletes stored file" do
      attacher.file = Shrine.upload(fakeio, "other_store")
      attacher.destroy_attached

      expect(attacher.file.not_nil!.exists?).to be_false
    end

    it "doesn't delete cached files" do
      attacher.file = Shrine.upload(fakeio, "cache")
      attacher.destroy_attached

      expect(attacher.file.not_nil!.exists?).to be_true
    end

    it "handles no attached file" do
      expect { attacher.destroy_attached }.to_not raise_error
    end
  end

  describe "#destroy" do
    it "deletes attached file" do
      attacher.file = attacher.upload(fakeio)

      expect { attacher.destroy }.to_not raise_error
    end

    it "handles no attached file" do
      expect { attacher.destroy }.to_not raise_error
    end
  end

  describe "#change" do
    it "sets the uploaded file" do
      file = attacher.upload(fakeio)
      attacher.change(file)

      expect(attacher.file).to eq(file)
    end

    it "returns the uploaded file" do
      file = attacher.upload(fakeio)

      expect(attacher.change(file)).to eq(file)
    end

    it "marks attacher as changed" do
      file = attacher.upload(fakeio)
      attacher.change(file)

      expect(attacher.changed?).to be_true
    end

    it "doesn't mark attacher as changed on same file" do
      attacher.file = attacher.upload(fakeio)
      attacher.change(attacher.file)

      expect(attacher.changed?).to be_false
    end
  end

  describe "#set" do
    it "sets the uploaded file" do
      file = attacher.upload(fakeio)
      attacher.set(file)

      expect(attacher.file).to eq(file)
    end

    it "returns the set file" do
      file = attacher.upload(fakeio)

      expect(attacher.set(file)).to eq(file)
    end

    it "doesn't mark attacher as changed" do
      attacher.set attacher.upload(fakeio)

      expect(attacher.changed?).to be_false
    end
  end

  describe "#get" do
    it "returns the attached file" do
      attacher.attach(fakeio)

      expect(attacher.get).to eq(attacher.file)
    end

    it "returns nil when no file is attached" do
      expect(attacher.get).to be_nil
    end
  end

  describe "#url" do
    it "returns the attached file URL" do
      attacher.attach(fakeio)

      expect(attacher.url).to eq(attacher.file.not_nil!.url)
    end

    it "returns nil when no file is attached" do
      expect(attacher.url).to be_nil
    end
  end

  describe "changed?" do
    it "returns true when the attachment has changed to another file" do
      attacher.attach(fakeio)

      expect(attacher.changed?).to be_true
    end

    it "returns true when the attachment has changed to nil" do
      attacher.file = attacher.upload(fakeio)
      attacher.attach(nil)

      expect(attacher.changed?).to be_true
    end

    it "returns false when attachment hasn't changed" do
      attacher.file = attacher.upload(fakeio)

      expect(attacher.changed?).to be_false
    end
  end

  describe "#attached?" do
    it "returns true when file is attached" do
      attacher.attach(fakeio)

      expect(attacher.attached?).to be_true
    end

    it "returns false when file is not attached" do
      expect(attacher.attached?).to be_false

      attacher.attach(nil)

      expect(attacher.attached?).to be_false
    end
  end

  describe "#cached?" do
    it "returns true when attached file is present and cached" do
      attacher.file = Shrine.upload(fakeio, "cache")

      expect(attacher.cached?).to eq(true)
    end

    it "returns true when specified file is present and cached" do
      expect(attacher.cached?(Shrine.upload(fakeio, "cache"))).to be_true
    end

    it "returns false when attached file is present and stored" do
      attacher.file = Shrine.upload(fakeio, "store")

      expect(attacher.cached?).to be_false
    end

    it "returns false when specified file is present and stored" do
      expect(attacher.cached?(Shrine.upload(fakeio, "store"))).to be_false
    end

    it "returns false when no file is attached" do
      expect(attacher.cached?).to be_false
    end

    it "returns false when specified file is nil" do
      expect(attacher.cached?(nil)).to be_false
    end
  end

  describe "#stored?" do
    it "returns true when attached file is present and stored" do
      attacher.file = Shrine.upload(fakeio, "store")

      expect(attacher.stored?).to be_true
    end

    it "returns true when specified file is present and stored" do
      expect(attacher.stored?(Shrine.upload(fakeio, "store"))).to be_true
    end

    it "returns false when attached file is present and cached" do
      attacher.file = Shrine.upload(fakeio, "cache")

      expect(attacher.stored?).to be_false
    end

    it "returns false when specified file is present and cached" do
      expect(attacher.stored?(Shrine.upload(fakeio, "cache"))).to be_false
    end

    it "returns false when no file is attached" do
      expect(attacher.stored?).to be_false
    end

    it "returns false when specified file is nil" do
      expect(attacher.stored?(nil)).to be_false
    end
  end

  describe "#data" do
    it "returns file data when file is attached" do
      file = attacher.attach(fakeio)

      expect(attacher.data).to eq(file.not_nil!.data)
    end

    it "returns nil when no file is attached" do
      expect(attacher.data).to be_nil
    end
  end

  describe "#load_data" do
    it "loads file from given file data" do
      file = attacher.upload(fakeio)
      attacher.load_data(file.data)

      expect(attacher.file).to eq(file)
    end

    it "handles NamedTuple" do
      file = attacher.upload(fakeio)
      attacher.load_data(
        id: file.id,
        storage_key: file.storage_key,
        metadata: file.metadata,
      )

      expect(attacher.file).to eq(file)
    end

    it "clears file when given data is nil" do
      attacher.file = attacher.upload(fakeio)
      attacher.load_data(nil)

      expect(attacher.file).to be_nil
    end
  end

  describe "#file=" do
    it "sets the file" do
      file = attacher.upload(fakeio)
      attacher.file = file

      expect(attacher.file).to eq(file)
    end

    it "accepts nil" do
      attacher.attach(fakeio)
      attacher.file = nil

      expect(attacher.file).to be_nil
    end
  end

  describe "#file" do
    it "returns set file" do
      file = attacher.upload(fakeio)
      attacher.file = file

      expect(attacher.file).to eq(file)
    end

    it "returns nil when no file is set" do
      expect(attacher.file).to be_nil
    end
  end

  describe "#file!" do
    it "returns set file" do
      file = attacher.upload(fakeio)
      attacher.file = file

      expect(attacher.file!).to eq(file)
    end

    it "raises exception" do
      expect { attacher.file! }.to raise_error(Shrine::Error)
    end
  end

  describe "#upload_file" do
    it "instantiates an uploaded file with JSON data" do
      file = attacher.upload(fakeio)

      expect(attacher.uploaded_file(file.to_json)).to eq(file)
    end

    it "instantiates an uploaded file with Hash data" do
      file = attacher.upload(fakeio)

      expect(attacher.uploaded_file(file.data)).to eq(file)
    end

    it "returns file with UploadedFile" do
      file = attacher.upload(fakeio)

      expect(attacher.uploaded_file(file)).to eq(file)
    end
  end
end
