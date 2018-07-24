module Api
    module V1
        class DocsController < ApiController
            # respond only to JSON requests
            respond_to :json
            respond_to :html, only: []
            respond_to :xml, only: []

            # curl localhost:4600/api/index?query=%7B%22lat%22%3A1.23%2C%22long%22%3A2.34%2C%22radius%22%3A100%2C%22duration%22%3A14%7D
            def seismic
                query = params[:query].to_s
                query_parsed = JSON.parse(query) rescue Hash.new()
                lat = query_parsed["lat"].to_f
                long = query_parsed["long"].to_f
                radius = query_parsed["radius"].to_f
                if radius == 0.0
                    radius = 30000
                end
                duration = query_parsed["duration"].to_i
                if duration == 0
                    duration = 365
                end
                last = query_parsed["last"].to_i

                response = HTTParty.get('http://geoweb.zamg.ac.at/static/event/lastday.json')
                if response.code.to_s == "200"
                    data = []
                    Geokit::default_units = :kms
                    Geokit::default_formula = :sphere
                    home=Geokit::LatLng.new(lat, long)
                    # iterate over all elements
                    response.parsed_response["features"].each do |item|
                        point = Geokit::LatLng.new(item["properties"]["lat"], 
                                                   item["properties"]["lon"])
                        time = item["properties"]["time"]
                        id = item["id"].to_i
                        distance = home.distance_to(point)
                        if ((distance <= radius) &&
                            (Date.parse(time) >= Date.today-duration.days) &&
                            (id > last))
                                data << item
                        end
                    end
                    data_string = data.to_s.gsub("=>",":")
                    retVal = Hash.new()
                    retVal["data"] = data
                    retVal["source"] = Hash.new()
                    data_hash = Digest::SHA256.hexdigest(data_string)
                    retVal["source"]["data-hash"] = data_hash

                    sig_url = ENV["SIGNATURE_SERVICE"].to_s + "/api/sign"
                    response = HTTParty.post(
                        sig_url, 
                        headers: { 'Content-Type' => 'application/json' },
                        body: {data: Base64.strict_encode64(data_string)}.to_json)
                    source_hash = ""
                    if response.code.to_s == "200"
                        retVal["source"]["email"] = response.parsed_response["email"]
                        signature = response.parsed_response["signature"]
                        retVal["source"]["signature"] = signature
                        source_hash = Digest::SHA256.hexdigest(signature)
                        retVal["source"]["signature-hash"] = source_hash
                    else
                        source_hash = data_hash
                    end
                    response = HTTParty.post("https://blockchain.ownyourdata.eu/api/doc?hash=" + source_hash)
                    if response.code.to_s == "200"
                    	if response.parsed_response["address"] == ""
                    		retVal["source"]["hash-verification"] = "https://seal.ownyourdata.eu/en?hash=" + source_hash
                    	else
                    		retVal["source"]["hash-verification"] = response.parsed_response["address"]
                    	end
                    end
                    retVal["source"]["comment"] = "http://geoweb.zamg.ac.at/static/event/lastday.json"
	                render json: retVal, 
	                       status: 200
	             else
	                render json: {"error": response.code.to_s},
	                       status: 500
	            end
            end
        end
    end
end
