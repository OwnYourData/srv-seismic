Rails.application.routes.draw do
	namespace :api, defaults: { format: :json } do
		scope module: :v1, constraints: ApiConstraints.new(version: 1, default: true) do
			match 'index',   to: 'docs#seismic', via: 'get'
			match 'seismic', to: 'docs#seismic', via: 'get'
		end
	end
end
