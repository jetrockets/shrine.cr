require "sqlite3"
require "./base"

 class Shrine
     module Storage
       class SQLite < Storage::Base 
         def initialize(db_path : String, @table : String = "shrine_files")
            @db = DB.open("sqlite3://#{db_path}")
           create_table_if_not_exists
        end

    def upload(io : IO, id : String, metadata : Hash(String, String)? = nil, **options)
      data = io.gets_to_end
      metadata_json = metadata.try(&.to_json)
      
      @db.exec("INSERT INTO #{@table} (id, data, metadata) VALUES (?, ?, ?)", 
               id, data, metadata_json) 
    end

    def open(id : String) : IO
      if row = @db.query_one?("SELECT data FROM #{@table} WHERE id = ?", id, as: String)
        IO::Memory.new(row)
      else
        raise FileNotFound.new("file #{id} not found")
      end
    end

    def url(id : String, **options) : String
      "sqlite://#{@db.uri}/#{@table}/#{id}"
    end

    def exists?(id : String) : Bool
      @db.scalar("SELECT COUNT(*) FROM #{@table} WHERE id = ?", id).as(Int64) > 0
    end

    def delete(id : String)
      @db.exec("DELETE FROM #{@table} WHERE id = ?", id)
    end

    # SQLite doesn't need clean (no folders), but base requires it
    def clean(path : String)
      # Nothing to clean in SQLite
    end

    private def create_table_if_not_exists
      @db.exec <<-SQL
        CREATE TABLE IF NOT EXISTS #{@table} (
          id TEXT PRIMARY KEY,
          data BLOB NOT NULL,
          metadata TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      SQL
    end
  end
end