fs   = require 'fs'
exec = (require 'child_process').exec
path = require 'path'
fsu  = require 'fs-util'
connect  = require 'connect'

Crawler = require './crawler'

###
  Instantiate a crawler for the first url,
  Crawler returns a source and "<a href=''>" links url

  The links url are filtered ( i.e. external links are not crawled ),
  and then written to disk
###
module.exports = class Shoot

  # Dictionary (url -> true|false)
  crawled: {}

  # root address to be crawled
  root_url: null

  # array of pending_urls urls to crawl
  pending_urls: null

  # current number connections
  connections: 0

  # max number of connections
  max_connections: 10


  constructor:( @the, @cli )->
    @pending_urls = []

    # checks if address has http protocol defined, and if not define it
    if @cli.argv.address
      unless ~@cli.argv.address.indexOf 'http'
        @cli.argv.address = 'http://' + @cli.argv.address

    @root_url = @cli.argv.address or @cli.argv.file
    @crawl @root_url


  # crawl the given url and recursively crawl all the links found within
  crawl:( url )->
    return if @crawled[url] is true
    @crawled[url] = false

    console.log '>'.bold.yellow, url.grey 
    @connections++
    new Crawler @cli, url, ( source )=> 
      console.log '< '.bold.cyan, url.grey
      @connections--
      @crawled[url] = true
      @save_page url, source
      @after_crawl source


  # parses all links in the given source, and crawl them
  after_crawl:( source )->
    reg = /a href="(.+)"/g
    links = []

    # filters all links
    if source?
      while (match = reg.exec source)?
        relative = match[1]
        absolute = @root_url + relative
        if relative isnt '/' and not @crawled[absolute]?
          @pending_urls.push absolute

    # starting cralwing them until max_connections is reached
    while @connections < @max_connections and @pending_urls.length
      @crawl do @pending_urls.shift

    if @connections is 0
      do @finish


  # translates the url into a local address on the file system and saves
  # the page source
  save_page:( url, source )->
    # computes relative url
    relative_url = (url.replace @root_url, '') or '/'

    # computes output folder and file
    output_folder = path.join @cli.argv.output, relative_url
    output_file = path.join output_folder, 'index.html'

    # create folder if needed
    unless fs.existsSync output_folder
      fsu.mkdir_p output_folder
    
    # write file to disk and show status msg
    fs.writeFileSync output_file, source
    console.log '✓ '.green, relative_url


  finish:->
    # success status msg
    console.log '\n★  Application crawled successfully!'.green

    # aborts if webserver isn't needed
    return unless @cli.argv.server

    # simple static server with 'connect'
    @conn = connect()
    .use( connect.static @cli.argv.output )
    .listen @cli.argv.port

    # webserver start msg
    address = 'http://localhost:' + @cli.argv.port
    console.log '\nPreview server started at: \n\t'.grey, address