def test_http_get
  url = "http://localhost:8080"
  response = HTTPLite.get(url)
  if response[:status] == 200
    p response[:body]
  end
end

def updateCreditsFile
  return if $PokemonSystem.download_sprites != 0
  download_file(Settings::CREDITS_FILE_URL,Settings::CREDITS_FILE_PATH,)
end

def createCustomSpriteFolders()
  if !Dir.exist?(Settings::CUSTOM_BATTLERS_FOLDER)
    Dir.mkdir(Settings::CUSTOM_BATTLERS_FOLDER)
  end
  if !Dir.exist?(Settings::CUSTOM_BATTLERS_FOLDER_INDEXED)
    Dir.mkdir(Settings::CUSTOM_BATTLERS_FOLDER_INDEXED)
  end
end

def download_file(url, saveLocation)
  begin
    response = HTTPLite.get(url)
    if response[:status] == 200
      File.open(saveLocation, "wb") do |file|
        file.write(response[:body])
      end
      echo _INTL("\nDownloaded file {1} to {2}", url, saveLocation)
      return saveLocation
    end
    return nil
  rescue MKXPError, Errno::ENOENT => error
    echo error
    return nil
  end
end

def download_pokemon_sprite_if_missing(body, head)
  return if $PokemonSystem.download_sprites != 0
  get_fusion_sprite_path(head,body)
end



def download_sprite(base_path, head_id, body_id, saveLocation = "Graphics/temp", alt_letter= "")
  begin
    downloaded_file_name = _INTL("{1}/{2}.{3}{4}.png", saveLocation, head_id, body_id,alt_letter)
    if !body_id
      downloaded_file_name = _INTL("{1}/{2}{3}.png", saveLocation, head_id,alt_letter)
    end

    return downloaded_file_name if pbResolveBitmap(downloaded_file_name)
    url = _INTL(base_path, head_id, body_id)
    if !body_id
      url = _INTL(base_path, head_id)
    end
    response = HTTPLite.get(url)
    if response[:status] == 200
      File.open(downloaded_file_name, "wb") do |file|
        file.write(response[:body])
      end
      echo _INTL("\nDownloaded file {1} to {2}", downloaded_file_name, saveLocation)
      return downloaded_file_name
    end
    return nil
  rescue MKXPError,Errno::ENOENT
    return nil
  end
end

def download_autogen_sprite(head_id, body_id)
  return nil if $PokemonSystem.download_sprites != 0
  url = "https://raw.githubusercontent.com/Aegide/autogen-fusion-sprites/master/Battlers/{1}/{1}.{2}.png"
  destPath = _INTL("{1}{2}", Settings::BATTLERS_FOLDER, head_id)
  sprite = download_sprite(_INTL(url, head_id, body_id), head_id, body_id, destPath)
  return sprite if sprite
  return nil
end

def download_custom_sprite(head_id, body_id)
  return nil if $PokemonSystem.download_sprites != 0
  url = "https://raw.githubusercontent.com/infinitefusion/sprites/main/CustomBattlers/{1}.{2}.png"
  destPath = _INTL("{1}{2}", Settings::CUSTOM_BATTLERS_FOLDER_INDEXED, head_id)
  if !Dir.exist?(destPath)
    Dir.mkdir(destPath)
  end

  sprite = download_sprite(_INTL(url, head_id, body_id), head_id, body_id, destPath)
  return sprite if sprite
  return nil
end

def download_unfused_alt_sprites(dex_num)
  base_url = "https://raw.githubusercontent.com/infinitefusion/sprites/main/Other/Base%20Sprites/{1}"
  extension = ".png"
  destPath = _INTL("{1}", Settings::CUSTOM_BASE_SPRITES_FOLDER)
  if !Dir.exist?(destPath)
    Dir.mkdir(destPath)
  end
  alt_url = _INTL(base_url,dex_num)  + extension
  download_sprite(alt_url, dex_num,nil, destPath )
  alphabet = ('a'..'z').to_a
  alphabet.each do |letter|
    alt_url = _INTL(base_url,dex_num) + letter + extension
    sprite = download_sprite(alt_url, dex_num,nil, destPath, letter)
    return if !sprite
  end
end

def download_alt_sprites(head_id,body_id)
  base_url = "https://raw.githubusercontent.com/infinitefusion/sprites/main/CustomBattlers/{1}.{2}"
  extension = ".png"
  destPath = _INTL("{1}{2}", Settings::CUSTOM_BATTLERS_FOLDER_INDEXED, head_id)
  if !Dir.exist?(destPath)
    Dir.mkdir(destPath)
  end
  alphabet = ('a'..'z').to_a
  alphabet.each do |letter|
    alt_url = base_url + letter + extension
    sprite = download_sprite(alt_url, head_id, body_id, destPath, letter)
    return if !sprite
  end
end


#format: [1.1.png, 1.2.png, etc.]
# https://api.github.com/repos/infinitefusion/contents/sprites/CustomBattlers
#   repo = "Aegide/custom-fusion-sprites"
#   folder = "CustomBattlers"
#

# def fetch_online_custom_sprites
#   page_start =1
#   page_end =2
#
#   repo = "infinitefusion/sprites"
#   folder = "CustomBattlers"
#   api_url = "https://api.github.com/repos/#{repo}/contents/#{folder}"
#
#   files = []
#   page = page_start
#
#   File.open(Settings::CUSTOM_SPRITES_FILE_PATH, "wb") do |csv|
#     loop do
#       break if page > page_end
#       response = HTTPLite.get(api_url, {'page' => page.to_s})
#       response_files = HTTPLite::JSON.parse(response[:body])
#       break if response_files.empty?
#       response_files.each do |file|
#         csv << [file['name']].to_s
#         csv << "\n"
#       end
#       page += 1
#     end
#   end
#
#
#   write_custom_sprites_csv(files)
# end


# Too many file to get everything without getting
# rate limited by github, so instead we're getting the
# files list from a  csv file that will be manually updated
# with each new spritepack

def updateOnlineCustomSpritesFile
  return if $PokemonSystem.download_sprites != 0
  download_file(Settings::SPRITES_FILE_URL,Settings::CUSTOM_SPRITES_FILE_PATH)
end


def list_online_custom_sprites(updateList=false)
  sprites_list= []
  File.foreach(Settings::CUSTOM_SPRITES_FILE_PATH) do |line|
    sprites_list << line
  end
  return sprites_list
end


GAME_VERSION_FORMAT_REGEX = /\A\d+(\.\d+)*\z/
def fetch_latest_game_version
  begin
    download_file(Settings::VERSION_FILE_URL,Settings::VERSION_FILE_PATH,)
    version_file = File.open(Settings::VERSION_FILE_PATH, "r")
    version = version_file.first
    version_file.close

    version_format_valid = version.match(GAME_VERSION_FORMAT_REGEX)

    return version if version_format_valid
    return nil
  rescue MKXPError, Errno::ENOENT => error
    echo error
    return nil
  end

end
