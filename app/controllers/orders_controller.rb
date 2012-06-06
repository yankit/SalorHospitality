# coding: UTF-8

# BillGastro -- The innovative Point Of Sales Software for your Restaurant
# Copyright (C) 2012-2013  Red (E) Tools LTD
# 
# See license.txt for the license applying to all files within this software.

class OrdersController < ApplicationController

  def index
    @tables = @current_user.tables.where(:vendor_id => @current_vendor).existing
    @categories = @current_vendor.categories.positioned
    @users = User.accessible_by(@current_user).active
    session[:admin_interface] = false
  end

  # happens only in invoice_form if user changes CostCenter or Tax of Order
  def update
    @order = get_model
    if params[:order][:tax_id]
      @order.update_attribute :tax_id, params[:order][:tax_id] 
      @order.items.existing.update_all :tax_id => nil
      @orders = @current_vendor.orders.where(:finished => false, :table_id => @order.table_id)
      @cost_centers = @current_vendor.cost_centers.existing.active
      @taxes = @current_vendor.taxes.existing
      render 'items/update'
    else
      @order.update_attribute(:cost_center_id, params[:order][:cost_center_id]) if params[:order][:cost_center_id]  
      render :nothing => true
    end
  end

  def show
    if params[:id] != 'last'
      @order = @current_vendor.orders.existing.find(params[:id])
    else
      @order = @current_vendor.orders.existing.find_all_by_finished(true).last
    end
    redirect_to '/' and return if not @order
    @previous_order, @next_order = neighbour_orders(@order)
    respond_to do |wants|
      wants.html
      wants.bill { render :text => generate_escpos_invoice(@order) }
    end
  end

  def by_nr
    @order = @current_vendor.orders.existing.find_by_nr(params[:nr])
    if @order
      redirect_to order_path(@order)
    else
      redirect_to order_path(@current_vendor.orders.existing.last)
    end
  end

  def toggle_admin_interface
    if session[:admin_interface]
      session[:admin_interface] = !session[:admin_interface]
    else
      session[:admin_interface] = true
    end
    @tables = @current_user.tables.where(:vendor_id => @current_vendor).existing
  end

  def toggle_tax_colors
    @order = get_model
    if session[:display_tax_colors]
      session[:display_tax_colors] = !session[:display_tax_colors]
    else
      session[:display_tax_colors] = true
    end
    @orders = @current_vendor.orders.existing.where(:finished => false, :table_id => @order.table_id)
    @cost_centers = @current_vendor.cost_centers.existing.active
    @taxes = @current_vendor.taxes.existing
    render 'items/update'
  end

  def storno
    @order = get_model
  end

  def update_ajax
    case params[:currentview]
      when 'refund', 'show'
        @order = get_model
        @order.print(['invoice'],@current_vendor.vendor_printers.find_by_id(params[:printer]))
        render :nothing => true and return
      when 'invoice'
        @order = get_model
        @order.finish
        @order.print(['invoice'], @current_vendor.vendor_printers.find_by_id(params[:printer])) if params[:printer]
        @orders = @current_vendor.orders.existing.where(:finished => false, :table_id => @order.table_id)
        if @orders.empty?
          @order.table.update_attribute :user, nil if @orders.empty?
          render :js => "route('tables', #{@order.table_id}); update_tables();" and return
        else
          @orders = @current_vendor.orders.existing.where(:finished => false, :table_id => @order.table_id)
          @taxes = @current_vendor.taxes.existing
          @cost_centers = @current_vendor.cost_centers.existing.active
          render 'go_to_invoice_form' and return
        end
      when 'table'
        case params['jsaction']
          when 'send'
            get_order
            @order.calculate_totals
            @order.regroup
            @order.update_associations(@current_user)
            if @order.items.existing.size.zero?
              @order.hide(@current_user.id)
              @order.unlink
            end
            render :nothing => true and return if @order.hidden
            case params[:target]
              when 'tables' then
                @order.print(['tickets'])
                render :nothing => true and return
              when 'table' then
                @order.finish
                @order.print(['tickets'])
                @orders = @current_vendor.orders.existing.where(:finished => false, :table_id => params[:order][:table_id])
                if @orders.empty?
                  @order.table.update_attribute :user, nil
                  render :js => "route('table',#{params[:order][:table_id]});" and return
                else
                  render :js => "route('tables',#{params[:order][:table_id]});" and return
                end
              when 'invoice' then
                @order.print(['tickets'])
                @orders = @current_vendor.orders.existing.where(:finished => false, :table_id => params[:order][:table_id])
                @taxes = @current_vendor.taxes.existing
                @cost_centers = @current_vendor.cost_centers.existing.active
                render 'go_to_invoice_form' and return
            end
          when 'send_and_print'
            get_order
            @order.calculate_totals
            @order.regroup
            @order.update_associations(@current_user)
            @order.hide(@current_user.id) if @order.items.existing.size.zero?
            if local_variant? and not @order.hidden
              @order.print(['tickets','invoice'], @current_vendor.vendor_printers.existing.first)
            elsif saas_variant? and not @order.hidden
              @order.print(['invoice'])
            end
            @order.finish
            @orders = @current_vendor.orders.existing.where(:finished => false, :table_id => @order.table.id)
            if @orders.empty?
              @order.table.update_attribute :user, nil
              render :js => "route('table', #{@order.table.id});" and return
            else
              render :js => "route('tables', #{@order.table.id});" and return
            end
          when 'move'
            get_order
            @order.move(params[:target_table_id])
            @order.print(['tickets'])
            @order.hide(@current_user.id) if @order.items.existing.size.zero?
            render :js => "route('tables', #{@order.table.id});" and return
        end
      when 'room'
        case params['jsaction']
          when 'send'
            get_booking
            @booking.update_associations(@current_user)
            if @booking.booking_items.size.zero?
              @booking.hide(@current_user.id)
            end
            render :js => "route('rooms');" and return
        end
    end
  end

  def last_invoices
    @unsettled_orders = @current_vendor.orders.existing.where(:settlement_id => nil, :finished => true, :user_id => @current_user.id).limit(5)
    if @current_user.role.permissions.include? 'finish_all_settlements'
      @users = @current_vendor.users
    elsif @current_user.role.permissions.include? 'finish_own_settlement'
      @users = [@current_user]
    else
      @users = []
    end
  end

  private
    def neighbour_orders(order)
      orders = @current_vendor.orders.existing.where(:finished => true)
      idx = orders.index(order)
      previous_order = orders[idx-1] if idx
      previous_order = order if previous_order.nil?
      next_order = orders[idx+1] if idx
      next_order = order if next_order.nil?
      return previous_order, next_order
    end

    def reduce_stocks(order)
      order.items.exisiting.each do |item|
        item.article.ingredients.each do |ingredient|
          ingredient.stock.balance -= item.count * ingredient.amount
          ingredient.stock.save
        end
      end
    end

    def get_order
      if params[:id]
        @order = get_model
      elsif params[:order] and params[:order][:table_id]
        # Reuse the order on table if possible
        @order = @current_vendor.orders.existing.where(:finished => false, :table_id => params[:order][:table_id]).first
      else
        raise "params[:order][:table_id] was not set. This is probably a JS issue and should never happen."
      end
      if @order
        @order.update_from_params(params)
      else
        @order = Order.create_from_params(params, @current_vendor, @current_user)
        @order.set_nr
      end
    end

    def get_booking
      @booking = Booking.accessible_by(@current_user).existing.find_by_id(params[:id]) if params[:id]
      if @booking
        @booking.update_from_params(params)
      else
        @booking = Booking.create_from_params(params, @current_vendor, @current_user)
      end
    end
end
