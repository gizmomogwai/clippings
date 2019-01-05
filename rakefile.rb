
desc "generate"
task :generate do
    sh "dub run -- /Volumes/Kindle/documents/My\\ Clippings.txt"
end


desc "upload"
task :upload do
    sh "scp -r out/all.html monica@maverick.local:'./Google\\ Drive/Quotes/Clippings.html'"
end


task :default => [:generate]
