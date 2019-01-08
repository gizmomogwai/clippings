
desc "generate"
task :generate do
    files = Dir.glob('monicas/*.txt').map{|i|"'#{i}'"}.join(' ')
    sh "dub run -- #{files}"
end


desc "upload"
task :upload do
    if `hostname`.strip.downcase == "maverick.local"
        sh "cp out/all.html ~/Google\\ Drive/Quotes/Clippings.html"
    else
        sh "scp -r out/all.html monica@maverick.local:'./Google\\ Drive/Quotes/Clippings.html'"
    end
end


task :default => [:generate]
