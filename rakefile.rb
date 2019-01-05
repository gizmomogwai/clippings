
desc "generate"
task :generate do
    sh "dub run -- /Volumes/Kindle/documents/My\\ Clippings.txt"
end


desc "upload"
task :upload do
    if `hostname`.strip.downcae == "maverick.local"
        sh "cp out/all.html ~/Google\\ Drive/Quotes/Clippings.html"
    else
        sh "scp -r out/all.html monica@maverick.local:'./Google\\ Drive/Quotes/Clippings.html'"
    end
end


task :default => [:generate]
