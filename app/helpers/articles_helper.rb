# BillGastro -- The innovative Point Of Sales Software for your Restaurant
# Copyright (C) 2011  Michael Franzl <michael@billgastro.com>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

module ArticlesHelper

  def add_ingredient_link(caption, frm)
    link_to_function caption do |page|
      ingredient = render(:partial => 'ingredient', :locals => { :frm => frm, :ingredient => Ingredient.new })
      page << %{
        var new_ingredient_id = "new_" + new Date().getTime();
        $('ingredients').insert({ bottom: '<tr id="' + new_ingredient_id + '">#{ escape_javascript ingredient }</tr>'.replace(/\\d/g, new_ingredient_id) });
        function HighlightEffect(element){
          new Effect.Highlight(element,
            {
              startcolor: "#3f5763",
              endcolor: "#243239",
              restorecolor: "#243239",
              duration: 1
            }
          )
        }
        HighlightEffect($(new_ingredient_id));
      }
    end
  end

  def add_quantity_link(caption, frm)
    link_to_function caption do |page|
      quantity = render(:partial => 'quantity', :locals => { :frm => frm, :quantity => Quantity.new })
      page << %{
        var new_quantity_id = "new_" + new Date().getTime();
        $('quantities_new').insert({ bottom: '<tr id="' + new_quantity_id + '">#{ escape_javascript quantity }</tr>'.replace(/\\d/g, new_quantity_id) });
        function HighlightEffect(element){
          new Effect.Highlight(element,
            {
              startcolor: "#3f5763",
              endcolor: "#243239",
              restorecolor: "#243239",
              duration: 1
            }
          )
        }
        HighlightEffect($(new_quantity_id));
      }
    end
  end

end
